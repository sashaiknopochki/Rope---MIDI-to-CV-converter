//___FILEHEADER___

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/MIDIMessages.h>

#import <algorithm>
#import <cstring>
#import <vector>

#import "Rope___MIDI_to_CV_converterExtensionParameterAddresses.h"


/*
 Rope___MIDI_to_CV_converterExtensionDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */
class Rope___MIDI_to_CV_converterExtensionDSPKernel {
public:
    void initialize(double inSampleRate) {
        mSampleRate = inSampleRate;
        for (int i = 0; i < 16; ++i) {
            mChannelFunctions[i] = FunctionType::Off;
            mChannelCCNumbers[i] = 1;
        }

        // Stage 3 default config for verification without UI:
        // ch1 gate, ch2 pitch, ch3 velocity, ch4 pitch bend, ch5 aftertouch, ch6 CC1.
        mChannelFunctions[0] = FunctionType::Gate;
        mChannelFunctions[1] = FunctionType::Pitch;
        mChannelFunctions[2] = FunctionType::Velocity;
        mChannelFunctions[3] = FunctionType::PitchBend;
        mChannelFunctions[4] = FunctionType::Aftertouch;
        mChannelFunctions[5] = FunctionType::CC;
        mChannelCCNumbers[5] = 1;
    }
    
    void deInitialize() {
    }
    
    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    void setParameter(AUParameterAddress address, AUValue value) {
        if (address >= channelFunctionBase && address <= channelFunctionLast) {
            const uint32_t channel = static_cast<uint32_t>(address - channelFunctionBase);
            uint32_t functionCode = static_cast<uint32_t>(value);
            if (functionCode > static_cast<uint32_t>(FunctionType::CC)) {
                functionCode = static_cast<uint32_t>(FunctionType::Off);
            }
            mChannelFunctions[channel] = static_cast<FunctionType>(functionCode);
            return;
        }

        if (address >= channelCCNumberBase && address <= channelCCNumberLast) {
            const uint32_t channel = static_cast<uint32_t>(address - channelCCNumberBase);
            int32_t ccNumber = static_cast<int32_t>(value);
            ccNumber = std::max(0, std::min(127, ccNumber));
            mChannelCCNumbers[channel] = static_cast<uint8_t>(ccNumber);
            return;
        }
    }

    AUValue getParameter(AUParameterAddress address) {
        if (address >= channelFunctionBase && address <= channelFunctionLast) {
            const uint32_t channel = static_cast<uint32_t>(address - channelFunctionBase);
            return static_cast<AUValue>(mChannelFunctions[channel]);
        }

        if (address >= channelCCNumberBase && address <= channelCCNumberLast) {
            const uint32_t channel = static_cast<uint32_t>(address - channelCCNumberBase);
            return static_cast<AUValue>(mChannelCCNumbers[channel]);
        }

        return 0.f;
    }
    
    // MARK: - Maximum Frames To Render
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }
    
    // MARK: - Internal Process
    void process(AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount, AudioBufferList* outputBufferList) {
        if (mBypassed) { return; }

        // Silence all channels first
        for (UInt32 i = 0; i < outputBufferList->mNumberBuffers; ++i) {
            memset(outputBufferList->mBuffers[i].mData, 0, outputBufferList->mBuffers[i].mDataByteSize);
        }

        for (UInt32 channel = 0; channel < outputBufferList->mNumberBuffers; ++channel) {
            float channelValue = cvValueForChannel(channel);
            float* channelBuffer = (float*)outputBufferList->mBuffers[channel].mData;
            for (AUAudioFrameCount frame = 0; frame < frameCount; ++frame) {
                channelBuffer[frame] = channelValue;
            }
        }
    }

    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }
                
            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }
                
            default:
                break;
        }
    }

    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto kernel = static_cast<Rope___MIDI_to_CV_converterExtensionDSPKernel*>(context);

            if (message.type != kMIDIMessageTypeChannelVoice2) { return; }

            switch (message.channelVoice2.status) {
                case kMIDICVStatusNoteOn: {
                    uint8_t note = message.channelVoice2.note.number;
                    uint16_t vel16 = message.channelVoice2.note.velocity;
                    // MIDI 2.0 velocity is 16-bit; treat velocity=0 as note off
                    if (vel16 == 0) {
                        if (kernel->mCurrentNote == note) { kernel->mGateOn = false; }
                    } else {
                        kernel->mGateOn = true;
                        kernel->mCurrentNote = note;
                        kernel->mCurrentVelocity = (uint8_t)(vel16 >> 9); // scale 16-bit to 7-bit
                    }
                    break;
                }
                case kMIDICVStatusNoteOff: {
                    uint8_t note = message.channelVoice2.note.number;
                    if (kernel->mCurrentNote == note) { kernel->mGateOn = false; }
                    break;
                }
                case kMIDICVStatusPitchBend: {
                    // 32-bit, center = 0x80000000; convert to -8192..+8191
                    int64_t raw = (int64_t)message.channelVoice2.pitchBend.data;
                    kernel->mPitchBend = (int16_t)((raw - 0x80000000LL) >> 18);
                    break;
                }
                case kMIDICVStatusChannelPressure: {
                    // 32-bit; scale to 7-bit
                    kernel->mAftertouch = (uint8_t)(message.channelVoice2.channelPressure.data >> 25);
                    break;
                }
                case kMIDICVStatusControlChange: {
                    uint8_t ccIndex = message.channelVoice2.controlChange.index;
                    // 32-bit value; scale to 7-bit
                    kernel->mCCValues[ccIndex] = (uint8_t)(message.channelVoice2.controlChange.data >> 25);
                    break;
                }
                default:
                    break;
            }
        };
        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }

    float cvValueForChannel(uint32_t channel) const {
        if (channel >= 16) { return 0.0f; }

        switch (mChannelFunctions[channel]) {
            case FunctionType::Off:
                return 0.0f;
            case FunctionType::Gate:
                return mGateOn ? 1.0f : 0.0f;
            case FunctionType::Pitch:
                return (static_cast<float>(mCurrentNote) - 60.0f) / 120.0f;
            case FunctionType::Velocity:
                return static_cast<float>(mCurrentVelocity) / 127.0f;
            case FunctionType::PitchBend:
                return static_cast<float>(mPitchBend) / 8192.0f;
            case FunctionType::Aftertouch:
                return static_cast<float>(mAftertouch) / 127.0f;
            case FunctionType::CC:
                return static_cast<float>(mCCValues[mChannelCCNumbers[channel]]) / 127.0f;
            default:
                return 0.0f;
        }
    }
    
    // MARK: Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;

    double mSampleRate = 44100.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;

    // MIDI state (written on render thread by handleMIDIEventList)
    bool mGateOn = false;
    uint8_t mCurrentNote = 60;
    uint8_t mCurrentVelocity = 0;
    int16_t mPitchBend = 0;       // -8192..+8191
    uint8_t mAftertouch = 0;
    uint8_t mCCValues[128] = {};

    enum FunctionType : uint8_t {
        Off = 0,
        Gate = 1,
        Pitch = 2,
        Velocity = 3,
        PitchBend = 4,
        Aftertouch = 5,
        CC = 6
    };

    FunctionType mChannelFunctions[16] = {};
    uint8_t mChannelCCNumbers[16] = {};
};
