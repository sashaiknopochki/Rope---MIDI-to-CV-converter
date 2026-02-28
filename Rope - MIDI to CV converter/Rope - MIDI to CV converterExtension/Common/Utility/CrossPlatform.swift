//
//  CrossPlatform.swift
//  Rope - MIDI to CV converterExtension
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import Foundation
import SwiftUI

#if os(iOS) || os(visionOS)
typealias HostingController = UIHostingController
#elseif os(macOS)
typealias HostingController = NSHostingController

extension NSView {
	
	func bringSubviewToFront(_ view: NSView) {
		// This function is a no-opp for macOS
	}
}
#endif
