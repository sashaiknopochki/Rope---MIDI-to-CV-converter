//
//  ContentView.swift
//  Rope - MIDI to CV converter
//
//  Created by Aleksandr Sudin on 28.02.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Rope")
                        .font(.largeTitle.bold())
                    Text("MIDI to CV Converter")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("Thanks for downloading Rope.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Rope is an Audio Unit v3 plugin, so it needs a host app like AUM to run.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                Text("Open your host app, insert Rope as an instrument plugin, then route its outputs to your DC-coupled interface.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            .padding(20)
        }
    }
}

#Preview {
    ContentView()
}
