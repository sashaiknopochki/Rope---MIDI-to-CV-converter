//
//  Parameters.swift
//  Rope - MIDI to CV converterExtension
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import Foundation
import AudioToolbox

private let outputChannelCount: AUParameterAddress = 16
private let allMIDISourceValue: AUValue = 0

let Rope___MIDI_to_CV_converterExtensionParameterSpecs: AUParameterTree = {
    var children: [AUParameterNode] = []
    let functionBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue)
    let ccBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue)
    let sourceBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue)
    let outputBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelOutputNumberBase.rawValue)

    for channel in 0..<outputChannelCount {
        let outputNumber = channel + 1
        let functionParam = AUParameterTree.createParameter(
            withIdentifier: "channel\(outputNumber)Function",
            name: "Output \(outputNumber) Function",
            address: functionBase + channel,
            min: 0,
            max: 6,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: ["Off", "Gate", "Pitch", "Velocity", "Pitch Bend", "Aftertouch", "CC"],
            dependentParameters: nil
        )
        if channel == 0 {
            functionParam.value = 1 // Gate
        } else if channel == 1 {
            functionParam.value = 2 // Pitch
        } else {
            functionParam.value = 0 // Off
        }
        children.append(functionParam)

        let ccParam = AUParameterTree.createParameter(
            withIdentifier: "channel\(outputNumber)CCNumber",
            name: "Output \(outputNumber) CC Number",
            address: ccBase + channel,
            min: 0,
            max: 127,
            unit: .midiController,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: nil,
            dependentParameters: nil
        )
        ccParam.value = 1
        children.append(ccParam)

        let sourceParam = AUParameterTree.createParameter(
            withIdentifier: "channel\(outputNumber)SourceMIDIChannel",
            name: "Output \(outputNumber) Source MIDI Channel",
            address: sourceBase + channel,
            min: 0,
            max: 16,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: ["All"] + (1...16).map { "Ch \($0)" },
            dependentParameters: nil
        )
        sourceParam.value = allMIDISourceValue
        children.append(sourceParam)

        let outputParam = AUParameterTree.createParameter(
            withIdentifier: "channel\(outputNumber)OutputNumber",
            name: "Output \(outputNumber) Hardware Output",
            address: outputBase + channel,
            min: 1,
            max: 16,
            unit: .indexed,
            unitName: nil,
            flags: [.flag_IsWritable, .flag_IsReadable],
            valueStrings: (1...16).map { "Out \($0)" },
            dependentParameters: nil
        )
        outputParam.value = AUValue(outputNumber)
        children.append(outputParam)
    }

    let global = AUParameterTree.createGroup(withIdentifier: "global", name: "Global", children: children)
    return AUParameterTree.createTree(withChildren: [global])
}()

extension AUParameterTree {
    func createAUParameterTree() -> AUParameterTree {
        self
    }
}
