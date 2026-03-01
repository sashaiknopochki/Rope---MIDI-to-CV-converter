//___FILEHEADER___

#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/MIDIMessages.h>

#import <algorithm>
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
    // No kernel parameters in Stage 2; channel config arrives in Stage 3.
    void setParameter(AUParameterAddress address, AUValue value) {
        // placeholder — Stage 3 will add channel function/CC params
    }

    AUValue getParameter(AUParameterAddress address) {
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

        // Channel 0: Gate — 1.0 when note on, 0.0 when note off
        if (outputBufferList->mNumberBuffers > 0) {
            float gateValue = mGateOn ? 1.0f : 0.0f;
            float* gateBuffer = (float*)outputBufferList->mBuffers[0].mData;
            for (AUAudioFrameCount frame = 0; frame < frameCount; ++frame) {
                gateBuffer[frame] = gateValue;
            }
        }

        // Channel 1: Pitch (1V/oct, C4=0V, each octave = 0.1 fullscale)
        if (outputBufferList->mNumberBuffers > 1) {
            float pitchValue = (mCurrentNote - 60) / 120.0f;
            float* pitchBuffer = (float*)outputBufferList->mBuffers[1].mData;
            for (AUAudioFrameCount frame = 0; frame < frameCount; ++frame) {
                pitchBuffer[frame] = pitchValue;
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
};
