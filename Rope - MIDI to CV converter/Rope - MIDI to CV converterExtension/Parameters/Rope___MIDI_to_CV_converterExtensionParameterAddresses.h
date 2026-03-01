//___FILEHEADER___

#pragma once

#include <AudioToolbox/AUParameters.h>

typedef NS_ENUM(AUParameterAddress, Rope___MIDI_to_CV_converterExtensionParameterAddress) {
    channelFunctionBase = 0,
    channelFunctionLast = 15,
    channelCCNumberBase = 100,
    channelCCNumberLast = 115
};
