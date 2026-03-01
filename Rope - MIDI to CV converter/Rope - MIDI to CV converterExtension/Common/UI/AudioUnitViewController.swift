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
    
    var hostingController: HostingController<Rope___MIDI_to_CV_converterExtensionMainView>?
    
    private var observation: NSKeyValueObservation?

	/* iOS View lifcycle
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Recreate any view related resources here..
	}

	public override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

		// Destroy any view related content here..
	}
	*/

	/* macOS View lifcycle
	public override func viewWillAppear() {
		super.viewWillAppear()
		
		// Recreate any view related resources here..
	}

	public override func viewDidDisappear() {
		super.viewDidDisappear()

		// Destroy any view related content here..
	}
	*/

	deinit {
	}

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Accessing the `audioUnit` parameter prompts the AU to be created via createAudioUnit(with:)
        guard let audioUnit = self.audioUnit else {
            return
        }
        configureSwiftUIView(audioUnit: audioUnit)
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
                self.configureSwiftUIView(audioUnit: audioUnit)
            }
        }
        
        audioUnit.setupParameterTree(Rope___MIDI_to_CV_converterExtensionParameterSpecs.createAUParameterTree())
        
        self.observation = audioUnit.observe(\.allParameterValues, options: [.new]) { object, change in
            guard let tree = audioUnit.parameterTree else { return }
            
            // This insures the Audio Unit gets initial values from the host.
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
    
    private func configureSwiftUIView(audioUnit: AUAudioUnit) {
        if let host = hostingController {
            host.removeFromParent()
            host.view.removeFromSuperview()
        }
        
        guard let observableParameterTree = audioUnit.observableParameterTree else {
            return
        }
        let content = Rope___MIDI_to_CV_converterExtensionMainView(parameterTree: observableParameterTree)
        let host = HostingController(rootView: content)
        self.addChild(host)
        host.view.frame = self.view.bounds
        self.view.addSubview(host.view)
        hostingController = host
        
        // Make sure the SwiftUI view fills the full area provided by the view controller
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.view.bringSubviewToFront(host.view)
    }
    
}
