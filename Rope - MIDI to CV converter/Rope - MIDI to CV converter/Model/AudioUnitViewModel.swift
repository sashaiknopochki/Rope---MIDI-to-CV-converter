//
//  AudioUnitViewModel.swift
//  Rope - MIDI to CV converter
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import SwiftUI
import AudioToolbox
import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var showMIDIContols: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded.."
    var viewController: ViewController?
}
