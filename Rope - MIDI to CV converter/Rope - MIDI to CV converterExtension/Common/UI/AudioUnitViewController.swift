//
//  AudioUnitViewController.swift
//  Rope - MIDI to CV converterExtension
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import Combine
import CoreAudioKit
import os
import SwiftUI

private let log = Logger(subsystem: "com.gracescale.Rope---MIDI-to-CV-converterExtension", category: "AudioUnitViewController")

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    var outputCardListModel: OutputCardListModel?

    private var observation: NSKeyValueObservation?
    private var outputFormatObservation: NSKeyValueObservation?
    private var modelStateObservation: AnyCancellable?

    private var rootHostingController: HostingController<Rope___MIDI_to_CV_converterExtensionMainView>?

    deinit {
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        applyAdaptivePreferredContentSize()

        // Accessing the `audioUnit` parameter prompts the AU to be created via createAudioUnit(with:)
        guard let audioUnit = self.audioUnit else {
            return
        }
        configureContent(audioUnit: audioUnit)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyAdaptivePreferredContentSize()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #unavailable(iOS 17.0) {
            super.traitCollectionDidChange(previousTraitCollection)
        }
        applyAdaptivePreferredContentSize()
    }

    @MainActor
    private func buildAudioUnit(componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try Rope___MIDI_to_CV_converterExtensionAudioUnit(componentDescription: componentDescription, options: [])

        guard let audioUnit = self.audioUnit as? Rope___MIDI_to_CV_converterExtensionAudioUnit else {
            log.error("Unable to create Rope___MIDI_to_CV_converterExtensionAudioUnit")
            return self.audioUnit!
        }

        defer {
            // Configure the SwiftUI view after creating the AU, instead of in viewDidLoad,
            // so that the parameter tree is set up before we build our @AUParameterUI properties
            DispatchQueue.main.async {
                self.configureContent(audioUnit: audioUnit)
            }
        }

        audioUnit.setupParameterTree(Rope___MIDI_to_CV_converterExtensionParameterSpecs.createAUParameterTree())

        self.observation = audioUnit.observe(\.allParameterValues, options: [.new]) { _, _ in
            guard let tree = audioUnit.parameterTree else { return }

            // This ensures the Audio Unit gets initial values from the host.
            for param in tree.allParameters { param.value = param.value }
        }

        guard audioUnit.parameterTree != nil else {
            log.error("Unable to access AU ParameterTree")
            return audioUnit
        }

        return audioUnit
    }

    nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        // Avoid deadlocking the extension host when this callback is already invoked on main.
        if Thread.isMainThread {
            return try MainActor.assumeIsolated {
                try self.buildAudioUnit(componentDescription: componentDescription)
            }
        }

        var result: Result<AUAudioUnit, Error>!
        DispatchQueue.main.sync {
            result = Result {
                try MainActor.assumeIsolated {
                    try self.buildAudioUnit(componentDescription: componentDescription)
                }
            }
        }
        return try result.get()
    }

    private func configureContent(audioUnit: AUAudioUnit) {
        outputFormatObservation = nil
        modelStateObservation = nil

        guard let parameterTree = audioUnit.parameterTree else {
            return
        }

        let ropeAudioUnit = audioUnit as? Rope___MIDI_to_CV_converterExtensionAudioUnit
        let restoredCards = ropeAudioUnit?.restoredOutputCardsForUI
        let model = OutputCardListModel(parameterTree: parameterTree, restoredCards: restoredCards)

        if let ropeAudioUnit {
            ropeAudioUnit.onHostOutputChannelCountChanged = { [weak self] channelCount in
                Task { @MainActor in
                    self?.outputCardListModel?.setHostOutputChannelCount(channelCount)
                }
            }
            model.setHostOutputChannelCount(ropeAudioUnit.hostOutputChannelCountForUI)
        }

        if audioUnit.outputBusses.count > 0 {
            let outputBus = audioUnit.outputBusses[0]
            if ropeAudioUnit == nil {
                model.setHostOutputChannelCount(Int(outputBus.format.channelCount))
            }
            outputFormatObservation = outputBus.observe(\.format, options: [.initial, .new]) { bus, _ in
                Task { @MainActor in
                    model.setHostOutputChannelCount(Int(bus.format.channelCount))
                }
            }
        }

        modelStateObservation = model.$hostOutputChannelCount.sink { [weak self] _ in
            guard let self else { return }
            self.installOrUpdateRootView(model: model)
            self.applyAdaptivePreferredContentSize()
        }

        outputCardListModel = model
        installOrUpdateRootView(model: model)
        applyAdaptivePreferredContentSize()
    }

    private func installOrUpdateRootView(model: OutputCardListModel) {
        let rootView = Rope___MIDI_to_CV_converterExtensionMainView(model: model)

        if let host = rootHostingController {
            host.rootView = rootView
            return
        }

        let host = HostingController(rootView: rootView)
        rootHostingController = host

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func applyAdaptivePreferredContentSize() {
        if traitCollection.horizontalSizeClass == .regular {
            preferredContentSize = CGSize(width: 744, height: 335)
        } else {
            preferredContentSize = CGSize(width: 406, height: 335)
        }
    }
}
