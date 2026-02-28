//
//  TypeAliases.swift
//  Rope - MIDI to CV converter
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import CoreMIDI
import AudioToolbox

#if os(iOS) || os(visionOS)
import UIKit

public typealias ViewController = UIViewController
#elseif os(macOS)
import AppKit

public typealias KitView = NSView
public typealias ViewController = NSViewController
#endif
