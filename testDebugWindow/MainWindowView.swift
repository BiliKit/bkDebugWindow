//
//  MainWindowView.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-12.
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    let windowId: String
    @ObservedObject var manager = WindowManager.shared
    @State private var counter = 0 {
        didSet {
            debugState.updateWatchVariable(name: "counter", value: counter, type: "Int")
        }
    }
    /// 调试状态对象
    @ObservedObject var debugState: DebugState = .shared

    var body: some View {
        VStack(spacing: 20) {
            Text("计数器: \(counter)")
                .font(.title)

            // 控制区域
            VStack(spacing: 12) {
                // 增加计数按钮
                Button("增加计数") {
                    incrementCounter()
                }
                .buttonStyle(MainWindowButtonStyle())

                // 重置窗口位置按钮
                Button("重置窗口位置") {
                    manager.snapDebugWindowToMain()
                }
                .buttonStyle(MainWindowButtonStyle())

                Button("切换动画模式") {
                    withAnimation {
                        manager.windowMode = manager.windowMode == .animation ? .direct : .animation
                    }
                }
                .buttonStyle(MainWindowButtonStyle(color: .blue))
                Button("显示调试窗口") {
                    withAnimation {
                      if manager.debugWindow?.isVisible ?? false {
                        manager.debugWindow?.orderOut(nil)
                      } else {
                        manager.debugWindow?.makeKeyAndOrderFront(nil)
                        manager.mainWindow?.makeKeyAndOrderFront(nil)
                      }
                    }
                }
                .buttonStyle(MainWindowButtonStyle(color: .blue))
                Button("测试信息") {
                    // 添加应用信息
                    let bundle = Bundle.main
                    debugState.addMessage(
                        "应用信息",
                        type: .info,
                        details: """
                        名称: \(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown")
                        版本: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                        构建版本: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                        """
                    )
                    // 添加系统信息
                        let processInfo = ProcessInfo.processInfo
                        debugState.addMessage(
                            "系统资源使用情况",
                            type: .system,
                            details: """
                            处理器数量: \(processInfo.processorCount)
                            活动处理器数量: \(processInfo.activeProcessorCount)
                            物理内存: \(String(format: "%.1f GB", Double(processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0))
                            系统启动时间: \(processInfo.systemUptime)s
                            热量状态: \(processInfo.thermalState.rawValue)
                            """
                        )
                }
                .buttonStyle(MainWindowButtonStyle(color: .red))
            }
            .padding()

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

extension MainWindowView {
    /// 增加计数器
    private func incrementCounter() {
        counter += 1
        #if DEBUG
        debugState.addMessage(
            "计数器增加到: \(counter)",
            type: .userAction,
            details: "Button tapped at \(Date()) \(#file) \(#function) \(#line)"
        )
        #endif
    }
}

extension MainWindowView {
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
    }
}

extension MainWindowView {
    private func getWindowSizeString() -> String {
        guard let window = manager.mainWindow else { return "未知" }
        return String(format: "%.0f × %.0f", window.frame.width, window.frame.height)
    }
}

extension MainWindowView {
    private func getDebugWindowStatus() -> String {
        if manager.debugWindow?.parent != nil {
            return "已吸附"
        } else {
            return "已分离"
        }
    }
}

extension MainWindowView {
    private func resetWindowPositions() {
        // 重置窗口位置的逻辑可以后续添加
    }
}