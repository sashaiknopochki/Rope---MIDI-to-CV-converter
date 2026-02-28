//___FILEHEADER___

#pragma once

#include <AudioToolbox/AUParameters.h>

typedef NS_ENUM(AUParameterAddress, Rope___MIDI_to_CV_converterExtensionParameterAddress) {
    sendNote = 0,
    midiNoteNumber = 1
};
