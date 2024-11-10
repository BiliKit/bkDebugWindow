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
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var debugState = DebugState.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("计数器: \(counter)")
                .font(.title)

            Button("增加计数") {
                counter += 1
                #if DEBUG
                debugState.addMessage(
                    "计数器增加到: \(counter)",
                    type: .userAction,
                    details: "Button tapped at \(Date())"
                )
                #endif
            }

            Button("触发测试事件") {
                #if DEBUG
                // 网络请求模拟
                debugState.addMessage(
                    "开始网络请求",
                    type: .network,
                    details: "GET https://api.example.com/data"
                )

                // 性能监控
                debugState.addMessage(
                    "内存使用: 256MB",
                    type: .performance,
                    details: "CPU: 5%, GPU: 2%"
                )

                // 系统事件
                debugState.addMessage(
                    "系统配置已更新",
                    type: .system,
                    details: "Theme: Dark, Language: zh-CN"
                )
                #endif
            }

            #if DEBUG
            Button(debugState.isWindowOpen ? "关闭调试窗口" : "打开调试窗口") {
                if debugState.isWindowOpen {
                    dismissWindow(id: "debug-window")
                    debugState.isWindowOpen = false
                } else {
                    openWindow(id: "debug-window")
                    debugState.isWindowOpen = true
                    // 给窗口一点时间创建
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
                           let mainWindow = NSApplication.shared.windows.first(where: { !($0.identifier?.rawValue == "debug-window") }) {
                            appDelegate.windowDelegate.setupDebugWindow(with: mainWindow)
                        }
                    }
                }
            }
            #endif
        }
        .padding()
        .onAppear {
            #if DEBUG
            debugState.addMessage("主窗口已加载", type: .info)
            // 确保按钮状态与窗口状态同步
            debugState.isWindowOpen = NSApplication.shared.windows.contains {
                $0.identifier?.rawValue == "debug-window" && $0.isVisible
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
}
