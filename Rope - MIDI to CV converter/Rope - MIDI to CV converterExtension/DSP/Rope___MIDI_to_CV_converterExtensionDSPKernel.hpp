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
    // Add a case for each parameter in Rope___MIDI_to_CV_converterExtensionParameterAddresses.h
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case Rope___MIDI_to_CV_converterExtensionParameterAddress::midiNoteNumber:
                mNextNoteToSend = (uint8_t)value;
                break;
            case Rope___MIDI_to_CV_converterExtensionParameterAddress::sendNote:
                mShouldSendNoteOn = (bool)value;
                break;
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
            case Rope___MIDI_to_CV_converterExtensionParameterAddress::midiNoteNumber:
                return (AUValue)mNextNoteToSend;
                
            case Rope___MIDI_to_CV_converterExtensionParameterAddress::sendNote:
                return (AUValue)mShouldSendNoteOn;
                
            default: return 0.f;
        }
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
        // CV output will be written here — silence for now
        for (UInt32 i = 0; i < outputBufferList->mNumberBuffers; ++i) {
            memset(outputBufferList->mBuffers[i].mData, 0, outputBufferList->mBuffers[i].mDataByteSize);
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
        /*
         // Parse UMP messages
         auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
         auto thisObject = static_cast<Rope___MIDI_to_CV_converterExtensionDSPKernel *>(context);

         switch (message.type) {
         case kMIDIMessageTypeChannelVoice2: {
         }
         break;

         default:
         break;
         }
         };
         MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
         */
        // incoming MIDI will be processed here
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }
    
    // MARK: Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;
    
    double mSampleRate = 44100.0;
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    
    bool mShouldSendNoteOn = false;
    bool mNoteIsCurrentlyOn = false;
    uint8_t mLastSentNote = 255;
    uint8_t mNextNoteToSend = 255;
};
