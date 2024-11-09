//
//  ContentView.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI

struct ContentView: View {
    @State private var counter = 0
    @Environment(\.openWindow) private var openWindow
    @StateObject private var debugState = DebugState.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("计数器: \(counter)")
                .font(.title)

            Button("增加计数") {
                counter += 1
                #if DEBUG
                DebugState.shared.addMessage("计数器增加到: \(counter)")
                #endif
            }

            Button("触发测试事件") {
                #if DEBUG
                DebugState.shared.addMessage("测试事件被触发")
                #endif
            }

            #if DEBUG
            Button("打开调试窗口") {
                if !debugState.isWindowOpen {
                    debugState.isWindowOpen = true
                    openWindow(id: "debug-window")
                }
            }
            #endif
        }
        .padding()
        .onAppear {
            #if DEBUG
            DebugState.shared.addMessage("主窗口已加载")
            #endif
        }
    }
}

#Preview {
    ContentView()
}
