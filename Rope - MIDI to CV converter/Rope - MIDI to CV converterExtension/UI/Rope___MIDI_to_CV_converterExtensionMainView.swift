//___FILEHEADER___

import SwiftUI

struct Rope___MIDI_to_CV_converterExtensionMainView: View {
    @ObservedObject var model: OutputCardListModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rope MIDI-to-CV")
                .font(.title3.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.cards) { card in
                        OutputCardView(
                            card: card,
                            onChange: model.updateCard
                        )
                    }
                }
            }
        }
        .padding()
    }
}
