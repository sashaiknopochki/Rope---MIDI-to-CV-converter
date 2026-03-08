//___FILEHEADER___

import SwiftUI

struct Rope___MIDI_to_CV_converterExtensionMainView: View {
    @ObservedObject var model: OutputCardListModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.hostOutputState {
            case .none:
                Text("Select a hardware output in the host application.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            case .single:
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let firstCard = model.cards.first(where: { $0.slotIndex == 0 }) {
                            OutputCardView(
                                card: firstCard,
                                onChange: model.updateCard
                            )
                        }
                        Text("Select a second hardware output in the host application to enable this output.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }

            case .stereo:
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

            Text("Rope MIDI-to-CV Converter")
                .font(.body)
        }
        .padding()
    }
}
