//
//  Parameters.swift
//  Rope - MIDI to CV converterExtension
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import Foundation
import AudioToolbox

private let outputChannelCount: AUParameterAddress = 16

let Rope___MIDI_to_CV_converterExtensionParameterSpecs: AUParameterTree = {
    var children: [AUParameterNode] = []
    let functionBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue)
    let ccBase = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue)

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
        functionParam.value = channel < 6 ? AUValue(channel + 1) : 0
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
    }

    let global = AUParameterTree.createGroup(withIdentifier: "global", name: "Global", children: children)
    return AUParameterTree.createTree(withChildren: [global])
}()

extension AUParameterTree {
    func createAUParameterTree() -> AUParameterTree {
        self
    }
}
