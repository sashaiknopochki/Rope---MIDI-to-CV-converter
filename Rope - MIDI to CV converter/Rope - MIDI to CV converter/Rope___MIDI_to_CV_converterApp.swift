//___FILEHEADER___

import SwiftUI

@main
struct ___PACKAGENAMEASIDENTIFIER___App: App {
    private let hostModel = AudioUnitHostModel()

    var body: some Scene {
        WindowGroup {
            ContentView(hostModel: hostModel)
        }
    }
}
