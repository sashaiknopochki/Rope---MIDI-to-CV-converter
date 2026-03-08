//___FILEHEADER___

import AVFoundation
import CoreAudioKit
import Foundation

public class Rope___MIDI_to_CV_converterExtensionAudioUnit: AUAudioUnit, @unchecked Sendable
{
    private static let outputCardsStateKey = "rope.outputCards.v1"
    private static let minimumPreferredViewHeight: CGFloat = 400

	// C++ Objects
	var kernel = Rope___MIDI_to_CV_converterExtensionDSPKernel()
    var processHelper: AUProcessHelper?

	private var outputBus: AUAudioUnitBus?
	private var _outputBusses: AUAudioUnitBusArray!
    private var pendingRestoredCards: [OutputCard]?
    private var hostOutputChannelCount: Int = 0 {
        didSet {
            guard oldValue != hostOutputChannelCount else { return }
            onHostOutputChannelCountChanged?(hostOutputChannelCount)
        }
    }

    var onHostOutputChannelCountChanged: ((Int) -> Void)?

	private var format:AVAudioFormat

	@objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        // Use DiscreteInOrder layout for multi-channel CV output.
        // standardFormatWithSampleRate:channels: only returns a valid format for 1-2 channels;
        // it returns nil for other counts, making the force-unwrap crash the extension process.
        let layoutTag: AudioChannelLayoutTag = kAudioChannelLayoutTag_DiscreteInOrder | 16
        let channelLayout = AVAudioChannelLayout(layoutTag: layoutTag)!
		self.format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channelLayout: channelLayout)
		try super.init(componentDescription: componentDescription, options: options)
		outputBus = try AUAudioUnitBus(format: self.format)
        outputBus?.maximumChannelCount = 16
		_outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])
        hostOutputChannelCount = Int(outputBus?.format.channelCount ?? 0)
        kernel.initialize(outputBus!.format.sampleRate)
        processHelper = AUProcessHelper(&kernel)
	}

	public override var outputBusses: AUAudioUnitBusArray {
		return _outputBusses
	}
    
    public override var  maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernel.maximumFramesToRender()
        }

        set {
            kernel.setMaximumFramesToRender(newValue)
        }
    }

    public override var  shouldBypassEffect: Bool {
        get {
            return kernel.isBypassed()
        }

        set {
            kernel.setBypass(newValue)
        }
    }

    // MARK: - MIDI
    public override var audioUnitMIDIProtocol: MIDIProtocolID {
        return kernel.AudioUnitMIDIProtocol()
    }

    // MARK: - Rendering
    public override var internalRenderBlock: AUInternalRenderBlock {
        return processHelper!.internalRenderBlock()
    }

    // Allocate resources required to render.
    // Subclassers should call the superclass implementation.
    public override func allocateRenderResources() throws {		
        kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.initialize(outputBus!.format.sampleRate)
        hostOutputChannelCount = Int(outputBus?.format.channelCount ?? 0)
		try super.allocateRenderResources()
	}

    // Deallocate resources allocated in allocateRenderResourcesAndReturnError:
    // Subclassers should call the superclass implementation.
    public override func deallocateRenderResources() {
        
        // Deallocate your resources.
        kernel.deInitialize()
        
        super.deallocateRenderResources()
    }

    public override func shouldChange(to format: AVAudioFormat, for bus: AUAudioUnitBus) -> Bool {
        let shouldChange = super.shouldChange(to: format, for: bus)
        if shouldChange, bus.busType == .output, bus.index == 0 {
            hostOutputChannelCount = Int(format.channelCount)
        }
        return shouldChange
    }

    public override func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        var supported = IndexSet()
        for (index, configuration) in availableViewConfigurations.enumerated() {
            if configuration.height >= Self.minimumPreferredViewHeight {
                supported.insert(index)
            }
        }
        return supported
    }

	public func setupParameterTree(_ parameterTree: AUParameterTree) {
		self.parameterTree = parameterTree

		// Set the Parameter default values before setting up the parameter callbacks
		for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
		}

		setupParameterCallbacks()
        applyPendingRestoredCardsIfNeeded()
	}

    var restoredOutputCardsForUI: [OutputCard]? {
        pendingRestoredCards
    }

    var hostOutputChannelCountForUI: Int {
        hostOutputChannelCount
    }

    public override var fullState: [String : Any]? {
        get {
            var state = super.fullState ?? [:]
            let cards = currentOutputCardsSnapshot()
            guard let encodedCards = try? JSONEncoder().encode(cards) else {
                return state
            }
            state[Self.outputCardsStateKey] = encodedCards
            return state
        }
        set {
            super.fullState = newValue

            guard
                let encodedCards = newValue?[Self.outputCardsStateKey] as? Data,
                let decodedCards = try? JSONDecoder().decode([OutputCard].self, from: encodedCards)
            else {
                pendingRestoredCards = nil
                return
            }

            pendingRestoredCards = sanitizeCards(decodedCards)
            applyPendingRestoredCardsIfNeeded()
        }
    }

	private func setupParameterCallbacks() {
		// implementorValueObserver is called when a parameter changes value.
		parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
            self?.kernel.setParameter(param.address, value)
		}

		// implementorValueProvider is called when the value needs to be refreshed.
		parameterTree?.implementorValueProvider = { [weak self] param in
            return self!.kernel.getParameter(param.address)
		}

		// A function to provide string representations of parameter values.
		parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
			guard let value = valuePtr?.pointee else {
				return "-"
			}
			return NSString.localizedStringWithFormat("%.f", value) as String
		}
	}

    private func applyPendingRestoredCardsIfNeeded() {
        guard let cards = pendingRestoredCards, let parameterTree else { return }
        for slot in 0..<16 {
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue + AUParameterAddress(slot)),
                value: 0,
                in: parameterTree
            )
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue + AUParameterAddress(slot)),
                value: 1,
                in: parameterTree
            )
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue + AUParameterAddress(slot)),
                value: 0,
                in: parameterTree
            )
        }

        for card in cards {
            let slot = AUParameterAddress(card.slotIndex)
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue + slot),
                value: AUValue(card.function.rawValue),
                in: parameterTree
            )
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue + slot),
                value: AUValue(card.ccNumber),
                in: parameterTree
            )
            writeParameter(
                at: AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue + slot),
                value: AUValue(card.sourceMIDIChannel),
                in: parameterTree
            )
        }
    }

    private func writeParameter(at address: AUParameterAddress, value: AUValue, in parameterTree: AUParameterTree) {
        guard let parameter = parameterTree.parameter(withAddress: address) else { return }
        parameter.value = value
        kernel.setParameter(address, value)
    }

    private func currentOutputCardsSnapshot() -> [OutputCard] {
        guard let parameterTree else {
            return pendingRestoredCards ?? []
        }

        var cards: [OutputCard] = []

        for slot in 0..<16 {
            let offset = AUParameterAddress(slot)
            let functionAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelFunctionBase.rawValue + offset)
            guard
                let functionValue = parameterTree.parameter(withAddress: functionAddress)?.value,
                let function = OutputFunction(rawValue: Int(functionValue)),
                function != .off
            else {
                continue
            }

            let ccAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelCCNumberBase.rawValue + offset)
            let sourceAddress = AUParameterAddress(Rope___MIDI_to_CV_converterExtensionParameterAddress.channelSourceMIDIChannelBase.rawValue + offset)

            cards.append(
                OutputCard(
                    slotIndex: slot,
                    sourceMIDIChannel: Int(parameterTree.parameter(withAddress: sourceAddress)?.value ?? 0),
                    function: function,
                    ccNumber: Int(parameterTree.parameter(withAddress: ccAddress)?.value ?? 1)
                )
            )
        }

        return sanitizeCards(cards)
    }

    private func sanitizeCards(_ cards: [OutputCard]) -> [OutputCard] {
        var seenSlots = Set<Int>()
        return cards
            .map { card in
                OutputCard(
                    slotIndex: max(0, min(15, card.slotIndex)),
                    sourceMIDIChannel: max(0, min(16, card.sourceMIDIChannel)),
                    function: card.function,
                    ccNumber: max(0, min(127, card.ccNumber))
                )
            }
            .filter { card in
                guard !seenSlots.contains(card.slotIndex) else { return false }
                seenSlots.insert(card.slotIndex)
                return true
            }
            .prefix(16)
            .sorted { $0.slotIndex < $1.slotIndex }
    }
}
