//
//  testDebugWindowApp.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI
import AppKit

@main
struct testDebugWindowApp: App {
    @NSApplicationDelegateAdaptor(baAppDelegate.self) var appDelegate

    var body: some Scene {
         WindowGroup {
             baMainWindowView(windowId: "MainWindow")
             .frame(width: 400, height: 500)
         }
         .windowResizability(.contentSize)
         .windowStyle(.hiddenTitleBar)
    }
}
