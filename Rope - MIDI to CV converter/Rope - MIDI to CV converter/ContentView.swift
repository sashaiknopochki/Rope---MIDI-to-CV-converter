//
//  ContentView.swift
//  Rope - MIDI to CV converter
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import AudioToolbox
import SwiftUI

struct ContentView: View {
    let hostModel: AudioUnitHostModel
    @State private var isSheetPresented = false
    
    var margin = 10.0
    var doubleMargin: Double {
        margin * 2.0
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Rope")
                        .font(.largeTitle.bold())
                    Text("MIDI to CV Converter")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("Use Rope as an AUv3 instrument plugin in AUM or another compatible host app. Rope converts incoming MIDI messages into DC-coupled CV signals for modular synthesizers via an audio interface such as the Expert Sleepers ES-8.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)

                Divider()

                VStack(spacing: 8) {
                    if hostModel.audioUnitCrashed {
                        Label("Plugin crashed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } else {
                        ValidationView(hostModel: hostModel, isSheetPresented: $isSheetPresented)
                        if let viewController = hostModel.viewModel.viewController {
                            AUViewControllerUI(viewController: viewController)
                                .padding(margin)
                        }
                    }
                }
            }
            .padding(doubleMargin)
        }
    }
}

#Preview {
    ContentView(hostModel: AudioUnitHostModel())
}
