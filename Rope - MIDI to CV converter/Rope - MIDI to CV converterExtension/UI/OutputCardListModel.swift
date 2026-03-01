import AudioToolbox
import Combine
import Foundation

enum OutputFunction: Int, CaseIterable, Identifiable, Codable {
    case off = 0
    case gate = 1
    case pitch = 2
    case velocity = 3
    case pitchBend = 4
    case aftertouch = 5
    case cc = 6

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .gate: return "Gate"
        case .pitch: return "Pitch"
        case .velocity: return "Velocity"
        case .pitchBend: return "Pitch Bend"
        case .aftertouch: return "Aftertouch"
        case .cc: return "CC"
        }
    }
}

struct OutputCard: Identifiable, Codable, Equatable {
    var id: Int { slotIndex }
    let slotIndex: Int
    var sourceMIDIChannel: Int   // 0 = All, 1...16 = MIDI channel
    var function: OutputFunction
    var ccNumber: Int
    var outputChannel: Int       // 1...16 hardware output
}

@MainActor
final class OutputCardListModel: ObservableObject {
    private static let maxCards = 16

    @Published var cards: [OutputCard] = []

    private let parameterTree: AUParameterTree

    init(parameterTree: AUParameterTree, restoredCards: [OutputCard]? = nil) {
        self.parameterTree = parameterTree
        if let restoredCards {
            self.cards = Self.sanitizeCards(restoredCards)
            pushConfigToKernel()
            return
        }

        self.cards = Self.readCards(from: parameterTree)

        if cards.isEmpty {
            cards = Self.defaultCards()
            pushConfigToKernel()
        }
    }

    func addCard() {
        guard cards.count < Self.maxCards else { return }

        let usedSlots = Set(cards.map(\.slotIndex))
        guard let firstOpenSlot = (0..<Self.maxCards).first(where: { !usedSlots.contains($0) }) else {
            return
        }

        let nextOutput = min(cards.count + 1, Self.maxCards)
        cards.append(
            OutputCard(
                slotIndex: firstOpenSlot,
                sourceMIDIChannel: 0,
                function: .gate,
                ccNumber: 1,
                outputChannel: nextOutput
            )
        )

        cards.sort { $0.slotIndex < $1.slotIndex }
        pushConfigToKernel()
    }

    func removeCard(id: Int) {
        cards.removeAll { $0.id == id }
        pushConfigToKernel()
    }

    func updateCard(_ updatedCard: OutputCard) {
        guard let index = cards.firstIndex(where: { $0.id == updatedCard.id }) else { return }
        cards[index] = sanitize(updatedCard)
        pushConfigToKernel()
    }

    func pushConfigToKernel() {
        // Clear all card slots first so deleted cards are reset in the kernel.
        for slot in 0..<Self.maxCards {
            writeFunction(.off, slot: slot)
            writeCCNumber(1, slot: slot)
            writeSourceMIDIChannel(0, slot: slot)
            writeOutputChannel(slot + 1, slot: slot)
        }

        for card in cards {
            let clampedCard = sanitize(card)
            writeFunction(clampedCard.function, slot: clampedCard.slotIndex)
            writeCCNumber(clampedCard.ccNumber, slot: clampedCard.slotIndex)
            writeSourceMIDIChannel(clampedCard.sourceMIDIChannel, slot: clampedCard.slotIndex)
            writeOutputChannel(clampedCard.outputChannel, slot: clampedCard.slotIndex)
        }
    }

    private func sanitize(_ card: OutputCard) -> OutputCard {
        OutputCard(
            slotIndex: max(0, min(Self.maxCards - 1, card.slotIndex)),
            sourceMIDIChannel: max(0, min(16, card.sourceMIDIChannel)),
            function: card.function,
            ccNumber: max(0, min(127, card.ccNumber)),
            outputChannel: max(1, min(16, card.outputChannel))
        )
    }

    private func writeFunction(_ function: OutputFunction, slot: Int) {
        guard let parameter = parameter(withAddress: functionAddress(slot: slot)) else { return }
        parameter.value = AUValue(function.rawValue)
    }

    private func writeCCNumber(_ ccNumber: Int, slot: Int) {
        guard let parameter = parameter(withAddress: ccAddress(slot: slot)) else { return }
        parameter.value = AUValue(ccNumber)
    }

    private func writeSourceMIDIChannel(_ sourceMIDIChannel: Int, slot: Int) {
        guard let parameter = parameter(withAddress: sourceAddress(slot: slot)) else { return }
        parameter.value = AUValue(sourceMIDIChannel)
    }

    private func writeOutputChannel(_ outputChannel: Int, slot: Int) {
        guard let parameter = parameter(withAddress: outputAddress(slot: slot)) else { return }
        parameter.value = AUValue(outputChannel)
    }

    private func parameter(withAddress address: AUParameterAddress) -> AUParameter? {
        parameterTree.parameter(withAddress: address)
    }

    private func functionAddress(slot: Int) -> AUParameterAddress {
        address(
            base: Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue,
            slot: slot
        )
    }

    private func ccAddress(slot: Int) -> AUParameterAddress {
        address(
            base: Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue,
            slot: slot
        )
    }

    private func sourceAddress(slot: Int) -> AUParameterAddress {
        address(
            base: Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue,
            slot: slot
        )
    }

    private func outputAddress(slot: Int) -> AUParameterAddress {
        address(
            base: Rope___MIDI_to_CV_converterExtensionParameterAddress.channelOutputNumberBase.rawValue,
            slot: slot
        )
    }

    private func address(
        base: Rope___MIDI_to_CV_converterExtensionParameterAddress.RawValue,
        slot: Int
    ) -> AUParameterAddress {
        AUParameterAddress(base + Rope___MIDI_to_CV_converterExtensionParameterAddress.RawValue(slot))
    }

    private static func readCards(from parameterTree: AUParameterTree) -> [OutputCard] {
        var loadedCards: [OutputCard] = []

        for slot in 0..<maxCards {
            let slotOffset = Rope___MIDI_to_CV_converterExtensionParameterAddress.RawValue(slot)
            let functionAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue + slotOffset)
            let ccAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue + slotOffset)
            let sourceAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue + slotOffset)
            let outputAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelOutputNumberBase.rawValue + slotOffset)

            guard let functionParameter = parameterTree.parameter(withAddress: functionAddress) else { continue }
            let functionRawValue = Int(functionParameter.value)
            let function = OutputFunction(rawValue: functionRawValue) ?? .off
            guard function != OutputFunction.off else { continue }

            let ccNumber = Int(parameterTree.parameter(withAddress: ccAddress)?.value ?? 1)
            let sourceMIDIChannel = Int(parameterTree.parameter(withAddress: sourceAddress)?.value ?? 0)
            let outputChannel = Int(parameterTree.parameter(withAddress: outputAddress)?.value ?? AUValue(slot + 1))

            loadedCards.append(
                OutputCard(
                    slotIndex: slot,
                    sourceMIDIChannel: max(0, min(16, sourceMIDIChannel)),
                    function: function,
                    ccNumber: max(0, min(127, ccNumber)),
                    outputChannel: max(1, min(16, outputChannel))
                )
            )
        }

        return loadedCards.sorted { $0.slotIndex < $1.slotIndex }
    }

    private static func defaultCards() -> [OutputCard] {
        [
            OutputCard(slotIndex: 0, sourceMIDIChannel: 0, function: .gate, ccNumber: 1, outputChannel: 1),
            OutputCard(slotIndex: 1, sourceMIDIChannel: 0, function: .pitch, ccNumber: 1, outputChannel: 2)
        ]
    }

    private static func sanitizeCards(_ cards: [OutputCard]) -> [OutputCard] {
        var seenSlots = Set<Int>()
        return cards
            .map { card in
                OutputCard(
                    slotIndex: max(0, min(maxCards - 1, card.slotIndex)),
                    sourceMIDIChannel: max(0, min(16, card.sourceMIDIChannel)),
                    function: card.function,
                    ccNumber: max(0, min(127, card.ccNumber)),
                    outputChannel: max(1, min(16, card.outputChannel))
                )
            }
            .filter { card in
                guard !seenSlots.contains(card.slotIndex) else { return false }
                seenSlots.insert(card.slotIndex)
                return true
            }
            .prefix(maxCards)
            .sorted { $0.slotIndex < $1.slotIndex }
    }
}
