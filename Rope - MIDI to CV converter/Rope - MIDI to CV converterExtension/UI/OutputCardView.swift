import SwiftUI

struct OutputCardView: View {
    var card: OutputCard
    var onChange: (OutputCard) -> Void

    private let gold = Color(red: 201.0 / 255.0, green: 162.0 / 255.0, blue: 39.0 / 255.0)
    private let silver = Color(red: 166.0 / 255.0, green: 166.0 / 255.0, blue: 166.0 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            parameterBlock(
                title: "MIDI CHANNEL",
                value: sourceMIDIChannelLabel
            ) {
                Button("All") { sourceBinding.wrappedValue = 0 }
                ForEach(1...16, id: \.self) { channel in
                    Button("Channel \(channel)") { sourceBinding.wrappedValue = channel }
                }
            }

            parameterBlock(
                title: "EVENT",
                value: functionBinding.wrappedValue.displayName
            ) {
                ForEach(eventOptions) { function in
                    Button(function.displayName) { functionBinding.wrappedValue = function }
                }
            }

            if card.function == .cc {
                parameterBlock(
                    title: "CC",
                    value: MIDICCNames.displayName(for: ccBinding.wrappedValue)
                ) {
                    ForEach(0...127, id: \.self) { ccNumber in
                        Button(MIDICCNames.displayName(for: ccNumber)) { ccBinding.wrappedValue = ccNumber }
                    }
                }
            }
        }
    }

    private var sourceMIDIChannelLabel: String {
        sourceBinding.wrappedValue == 0 ? "All" : "Channel \(sourceBinding.wrappedValue)"
    }

    private var eventOptions: [OutputFunction] {
        // AU host menu rendering currently reverses insertion order in this context.
        // Provide reverse input order so the visible order becomes Off -> ... -> CC.
        OutputFunction.allCases.sorted { $0.rawValue > $1.rawValue }
    }

    private func parameterBlock<MenuItems: View>(
        title: String,
        value: String,
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .tracking(0.9)
                .foregroundStyle(gold)

            Menu {
                menuItems()
            } label: {
                HStack {
                    Text(value)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(silver)
                )
            }
            .buttonStyle(.plain)
        }
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

struct OutputCardSlotView: View {
    @ObservedObject var model: OutputCardListModel
    let slotIndex: Int

    var body: some View {
        if let card = model.cards.first(where: { $0.slotIndex == slotIndex }) {
            OutputCardView(card: card, onChange: model.updateCard)
        } else {
            EmptyView()
        }
    }
}

struct OutputDisabledMessageCardView: View {
    let message: String

    private let gold = Color(red: 201.0 / 255.0, green: 162.0 / 255.0, blue: 39.0 / 255.0)

    var body: some View {
        Text(message)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(gold)
            .tracking(0.9)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
