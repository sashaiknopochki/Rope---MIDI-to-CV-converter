//___FILEHEADER___

import SwiftUI

struct Rope___MIDI_to_CV_converterExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rope MIDI-to-CV")
                .font(.headline)
            Text("Stage 3 channel configuration is active in the kernel parameters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Full card-based editor arrives in Stage 4.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
