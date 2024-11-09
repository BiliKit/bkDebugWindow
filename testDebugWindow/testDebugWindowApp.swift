//
//  testDebugWindowApp.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI

@main
struct testDebugWindowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        #if DEBUG
        Window("Debug", id: "debug-window") {
            DebugView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 300)
        .windowResizability(.contentSize)
        #endif
    }
}
