//___FILEHEADER___

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/MIDIMessages.h>

#import <algorithm>
#import <cstring>

#import "Rope___MIDI_to_CV_converterExtensionParameterAddresses.h"

class Rope___MIDI_to_CV_converterExtensionDSPKernel {
public:
    void initialize(double inSampleRate) {
        mSampleRate = inSampleRate;

        for (int i = 0; i < kCardCount; ++i) {
            mCardFunctions[i] = FunctionType::Off;
            mCardCCNumbers[i] = 1;
            mCardSourceMIDIChannel[i] = kAnyMIDIChannelSource;
            mCardOutputNumber[i] = static_cast<uint8_t>(i + 1);
        }

        // Default UI state: two active cards.
        mCardFunctions[0] = FunctionType::Gate;
        mCardFunctions[1] = FunctionType::Pitch;

        clearMIDIState();
    }

    void deInitialize() {}

    bool isBypassed() {
        return mBypassed;
    }

    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }

    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= channelFunctionBase && address <= channelFunctionLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelFunctionBase);
            uint32_t functionCode = static_cast<uint32_t>(value);
            if (functionCode > static_cast<uint32_t>(FunctionType::CC)) {
                functionCode = static_cast<uint32_t>(FunctionType::Off);
            }
            mCardFunctions[cardIndex] = static_cast<FunctionType>(functionCode);
            return;
        }

        if (address >= channelCCNumberBase && address <= channelCCNumberLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelCCNumberBase);
            int32_t ccNumber = static_cast<int32_t>(value);
            ccNumber = std::clamp(ccNumber, 0, 127);
            mCardCCNumbers[cardIndex] = static_cast<uint8_t>(ccNumber);
            return;
        }

        if (address >= channelSourceMIDIChannelBase && address <= channelSourceMIDIChannelLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelSourceMIDIChannelBase);
            int32_t source = static_cast<int32_t>(value);
            source = std::clamp(source, 0, 16);
            mCardSourceMIDIChannel[cardIndex] = static_cast<uint8_t>(source);
            return;
        }

        if (address >= channelOutputNumberBase && address <= channelOutputNumberLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelOutputNumberBase);
            int32_t outputNumber = static_cast<int32_t>(value);
            outputNumber = std::clamp(outputNumber, 1, 16);
            mCardOutputNumber[cardIndex] = static_cast<uint8_t>(outputNumber);
            return;
        }
    }

    AUValue getParameter(AUParameterAddress address) {
        if (address >= channelFunctionBase && address <= channelFunctionLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelFunctionBase);
            return static_cast<AUValue>(mCardFunctions[cardIndex]);
        }

        if (address >= channelCCNumberBase && address <= channelCCNumberLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelCCNumberBase);
            return static_cast<AUValue>(mCardCCNumbers[cardIndex]);
        }

        if (address >= channelSourceMIDIChannelBase && address <= channelSourceMIDIChannelLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelSourceMIDIChannelBase);
            return static_cast<AUValue>(mCardSourceMIDIChannel[cardIndex]);
        }

        if (address >= channelOutputNumberBase && address <= channelOutputNumberLast) {
            const uint32_t cardIndex = static_cast<uint32_t>(address - channelOutputNumberBase);
            return static_cast<AUValue>(mCardOutputNumber[cardIndex]);
        }

        return 0.f;
    }

    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }

    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }

    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }

    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }

    void process(AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount, AudioBufferList* outputBufferList) {
        if (mBypassed) { return; }

        for (UInt32 i = 0; i < outputBufferList->mNumberBuffers; ++i) {
            memset(outputBufferList->mBuffers[i].mData, 0, outputBufferList->mBuffers[i].mDataByteSize);
        }

        for (UInt32 outputBufferIndex = 0; outputBufferIndex < outputBufferList->mNumberBuffers; ++outputBufferIndex) {
            float channelValue = summedCVValueForOutput(static_cast<uint8_t>(outputBufferIndex + 1));
            float* channelBuffer = static_cast<float*>(outputBufferList->mBuffers[outputBufferIndex].mData);
            for (AUAudioFrameCount frame = 0; frame < frameCount; ++frame) {
                channelBuffer[frame] = channelValue;
            }
        }
    }

    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter:
                handleParameterEvent(now, event->parameter);
                break;

            case AURenderEventMIDI:
                handleMIDI1Event(now, &event->MIDI);
                break;

            case AURenderEventMIDIEventList:
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;

            default:
                break;
        }
    }

    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto kernel = static_cast<Rope___MIDI_to_CV_converterExtensionDSPKernel*>(context);

            if (message.type != kMIDIMessageTypeChannelVoice2) { return; }

            uint8_t channel = static_cast<uint8_t>(message.channelVoice2.channel);
            if (channel >= kMIDIChannelCount) { return; }

            switch (message.channelVoice2.status) {
                case kMIDICVStatusNoteOn: {
                    uint8_t note = message.channelVoice2.note.number;
                    uint16_t velocity16 = message.channelVoice2.note.velocity;
                    if (velocity16 == 0) {
                        kernel->handleNoteOff(channel, note);
                    } else {
                        kernel->handleNoteOn(channel, note, static_cast<uint8_t>(velocity16 >> 9));
                    }
                    break;
                }
                case kMIDICVStatusNoteOff: {
                    uint8_t note = message.channelVoice2.note.number;
                    kernel->handleNoteOff(channel, note);
                    break;
                }
                case kMIDICVStatusPitchBend: {
                    int64_t raw = static_cast<int64_t>(message.channelVoice2.pitchBend.data);
                    int16_t bend = static_cast<int16_t>((raw - 0x80000000LL) >> 18);
                    kernel->handlePitchBend(channel, bend);
                    break;
                }
                case kMIDICVStatusChannelPressure: {
                    uint8_t pressure = static_cast<uint8_t>(message.channelVoice2.channelPressure.data >> 25);
                    kernel->handleChannelPressure(channel, pressure);
                    break;
                }
                case kMIDICVStatusControlChange: {
                    uint8_t ccIndex = message.channelVoice2.controlChange.index;
                    if (ccIndex < 128) {
                        uint8_t ccValue = static_cast<uint8_t>(message.channelVoice2.controlChange.data >> 25);
                        kernel->handleCC(channel, ccIndex, ccValue);
                    }
                    break;
                }
                default:
                    break;
            }
        };

        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }

    void handleMIDI1Event(AUEventSampleTime now, AUMIDIEvent const* midiEvent) {
        if (midiEvent == nullptr || midiEvent->length < 1) { return; }

        const uint8_t status = midiEvent->data[0];
        const uint8_t type = static_cast<uint8_t>(status & 0xF0);
        const uint8_t channel = static_cast<uint8_t>(status & 0x0F);
        if (channel >= kMIDIChannelCount) { return; }

        switch (type) {
            case 0x80: { // Note Off
                if (midiEvent->length < 2) { return; }
                const uint8_t note = midiEvent->data[1] & 0x7F;
                handleNoteOff(channel, note);
                break;
            }

            case 0x90: { // Note On
                if (midiEvent->length < 3) { return; }
                const uint8_t note = midiEvent->data[1] & 0x7F;
                const uint8_t velocity = midiEvent->data[2] & 0x7F;
                if (velocity == 0) {
                    handleNoteOff(channel, note);
                } else {
                    handleNoteOn(channel, note, velocity);
                }
                break;
            }

            case 0xB0: { // CC
                if (midiEvent->length < 3) { return; }
                const uint8_t ccIndex = midiEvent->data[1] & 0x7F;
                const uint8_t ccValue = midiEvent->data[2] & 0x7F;
                handleCC(channel, ccIndex, ccValue);
                break;
            }

            case 0xD0: { // Channel Pressure
                if (midiEvent->length < 2) { return; }
                const uint8_t pressure = midiEvent->data[1] & 0x7F;
                handleChannelPressure(channel, pressure);
                break;
            }

            case 0xE0: { // Pitch Bend
                if (midiEvent->length < 3) { return; }
                const int32_t bend14 = (static_cast<int32_t>(midiEvent->data[1] & 0x7F))
                    | (static_cast<int32_t>(midiEvent->data[2] & 0x7F) << 7);
                const int16_t bend = static_cast<int16_t>(bend14 - 8192);
                handlePitchBend(channel, bend);
                break;
            }

            default:
                break;
        }
    }

    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }

private:
    static constexpr uint8_t kCardCount = 16;
    static constexpr uint8_t kMIDIChannelCount = 16;
    static constexpr uint8_t kAnyMIDIChannelSource = 0;

    enum FunctionType : uint8_t {
        Off = 0,
        Gate = 1,
        Pitch = 2,
        Velocity = 3,
        PitchBend = 4,
        Aftertouch = 5,
        CC = 6
    };

    void clearMIDIState() {
        memset(mGateOn, 0, sizeof(mGateOn));
        memset(mCurrentNote, 60, sizeof(mCurrentNote));
        memset(mCurrentVelocity, 0, sizeof(mCurrentVelocity));
        memset(mPitchBend, 0, sizeof(mPitchBend));
        memset(mAftertouch, 0, sizeof(mAftertouch));
        memset(mCCValues, 0, sizeof(mCCValues));
        memset(mAnyCCValues, 0, sizeof(mAnyCCValues));

        mAnyGateOn = false;
        mLastAnyNote = 60;
        mLastAnyVelocity = 0;
        mLastAnyPitchBend = 0;
        mLastAnyAftertouch = 0;
    }

    bool isAnyGateOn() const {
        for (uint8_t i = 0; i < kMIDIChannelCount; ++i) {
            if (mGateOn[i]) { return true; }
        }
        return false;
    }

    void handleNoteOn(uint8_t channel, uint8_t note, uint8_t velocity) {
        mGateOn[channel] = true;
        mCurrentNote[channel] = note;
        mCurrentVelocity[channel] = velocity;

        mAnyGateOn = true;
        mLastAnyNote = note;
        mLastAnyVelocity = velocity;
    }

    void handleNoteOff(uint8_t channel, uint8_t note) {
        if (mCurrentNote[channel] == note) {
            mGateOn[channel] = false;
        }
        mAnyGateOn = isAnyGateOn();
    }

    void handlePitchBend(uint8_t channel, int16_t bend) {
        mPitchBend[channel] = bend;
        mLastAnyPitchBend = bend;
    }

    void handleChannelPressure(uint8_t channel, uint8_t pressure) {
        mAftertouch[channel] = pressure;
        mLastAnyAftertouch = pressure;
    }

    void handleCC(uint8_t channel, uint8_t ccIndex, uint8_t ccValue) {
        if (ccIndex >= 128) { return; }
        mCCValues[channel][ccIndex] = ccValue;
        mAnyCCValues[ccIndex] = ccValue;
    }

    float cvValueForCard(uint8_t cardIndex) const {
        if (cardIndex >= kCardCount) { return 0.0f; }

        const FunctionType function = mCardFunctions[cardIndex];
        if (function == FunctionType::Off) { return 0.0f; }

        const uint8_t source = mCardSourceMIDIChannel[cardIndex];
        const bool anySource = (source == kAnyMIDIChannelSource);
        const uint8_t midiIndex = anySource ? 0 : static_cast<uint8_t>(source - 1);

        switch (function) {
            case FunctionType::Gate:
                return anySource ? (mAnyGateOn ? 1.0f : 0.0f) : (mGateOn[midiIndex] ? 1.0f : 0.0f);

            case FunctionType::Pitch:
                return anySource
                    ? (static_cast<float>(mLastAnyNote) - 60.0f) / 120.0f
                    : (static_cast<float>(mCurrentNote[midiIndex]) - 60.0f) / 120.0f;

            case FunctionType::Velocity:
                return anySource
                    ? static_cast<float>(mLastAnyVelocity) / 127.0f
                    : static_cast<float>(mCurrentVelocity[midiIndex]) / 127.0f;

            case FunctionType::PitchBend:
                return anySource
                    ? static_cast<float>(mLastAnyPitchBend) / 8192.0f
                    : static_cast<float>(mPitchBend[midiIndex]) / 8192.0f;

            case FunctionType::Aftertouch:
                return anySource
                    ? static_cast<float>(mLastAnyAftertouch) / 127.0f
                    : static_cast<float>(mAftertouch[midiIndex]) / 127.0f;

            case FunctionType::CC:
                if (mCardCCNumbers[cardIndex] >= 128) { return 0.0f; }
                return anySource
                    ? static_cast<float>(mAnyCCValues[mCardCCNumbers[cardIndex]]) / 127.0f
                    : static_cast<float>(mCCValues[midiIndex][mCardCCNumbers[cardIndex]]) / 127.0f;

            default:
                return 0.0f;
        }
    }

    float summedCVValueForOutput(uint8_t outputNumber) const {
        float sum = 0.0f;
        for (uint8_t cardIndex = 0; cardIndex < kCardCount; ++cardIndex) {
            if (mCardOutputNumber[cardIndex] != outputNumber) { continue; }
            sum += cvValueForCard(cardIndex);
        }
        return std::clamp(sum, -1.0f, 1.0f);
    }

    AUHostMusicalContextBlock mMusicalContextBlock;

    double mSampleRate = 44100.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;

    // Per-card configuration
    FunctionType mCardFunctions[kCardCount] = {};
    uint8_t mCardCCNumbers[kCardCount] = {};
    uint8_t mCardSourceMIDIChannel[kCardCount] = {};
    uint8_t mCardOutputNumber[kCardCount] = {};

    // MIDI state per source channel
    bool mGateOn[kMIDIChannelCount] = {};
    uint8_t mCurrentNote[kMIDIChannelCount] = {};
    uint8_t mCurrentVelocity[kMIDIChannelCount] = {};
    int16_t mPitchBend[kMIDIChannelCount] = {};
    uint8_t mAftertouch[kMIDIChannelCount] = {};
    uint8_t mCCValues[kMIDIChannelCount][128] = {};

    // Aggregated "All channels" state
    bool mAnyGateOn = false;
    uint8_t mLastAnyNote = 60;
    uint8_t mLastAnyVelocity = 0;
    int16_t mLastAnyPitchBend = 0;
    uint8_t mLastAnyAftertouch = 0;
    uint8_t mAnyCCValues[128] = {};
};
