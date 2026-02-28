//___FILEHEADER___

import SwiftUI

struct Rope___MIDI_to_CV_converterExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack {
            ParameterSlider(param: parameterTree.global.midiNoteNumber)
                .padding()
            MomentaryButton(
                "Play note",
                param: parameterTree.global.sendNote
            )
        }
    }
}
