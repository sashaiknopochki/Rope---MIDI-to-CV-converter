import SwiftUI

struct OutputCardView: View {
    var card: OutputCard
    var onChange: (OutputCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CV Output \(outputName)")
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text("Source MIDI Channel")
                Spacer()
                Picker("Source MIDI Channel", selection: sourceBinding) {
                    Text("All Channels").tag(0)
                    ForEach(1...16, id: \.self) { channel in
                        Text("Channel \(channel)").tag(channel)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Source MIDI event")
                Spacer()
                Picker("Source MIDI event", selection: functionBinding) {
                    ForEach(OutputFunction.allCases) { function in
                        Text(function.displayName).tag(function)
                    }
                }
                .pickerStyle(.menu)
            }

            if card.function == .cc {
                Picker("CC Number", selection: ccBinding) {
                    ForEach(0...127, id: \.self) { ccNumber in
                        Text(MIDICCNames.displayName(for: ccNumber)).tag(ccNumber)
                    }
                }
                .pickerStyle(.menu)
            }

        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var sourceBinding: Binding<Int> {
        Binding(
            get: { card.sourceMIDIChannel },
            set: { newValue in
                var updated = card
                updated.sourceMIDIChannel = newValue
                onChange(updated)
            }
        )
    }

    private var outputName: String {
        switch card.slotIndex {
        case 0: return "A"
        case 1: return "B"
        default: return "\(card.slotIndex + 1)"
        }
    }

    private var functionBinding: Binding<OutputFunction> {
        Binding(
            get: { card.function },
            set: { newValue in
                var updated = card
                updated.function = newValue
                onChange(updated)
            }
        )
    }

    private var ccBinding: Binding<Int> {
        Binding(
            get: { card.ccNumber },
            set: { newValue in
                var updated = card
                updated.ccNumber = newValue
                onChange(updated)
            }
        )
    }
}
