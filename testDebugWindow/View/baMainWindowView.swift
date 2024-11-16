//
//  MainWindowView.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-12.
//

import SwiftUI
import AppKit

struct baMainWindowView: View {
    let windowId: String

    @ObservedObject var manager = baWindowManager.shared
    @State private var counter = 0 {
        didSet {
            debugState.updateWatchVariable(name: "counter", value: counter, type: "Int")
        }
    }
    /// 调试状态对象
    @ObservedObject var debugState: baDebugState = .shared

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
                    #if DEVELOPMENT
                    debugState.info(
                        "应用信息",
                        details: """
                        名称: \(bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown")
                        版本: \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                        构建版本: \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                        """
                    )
                    #endif
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

extension baMainWindowView {
    /// 增加计数器
    private func incrementCounter() {
        counter += 1
        #if DEVELOPMENT
        debugState.userAction(
            "计数器增加到: \(counter)",
            details: "Button tapped at \(Date()) \(#file) \(#function) \(#line)"
        )
        #endif
    }
}

extension baMainWindowView {
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

extension baMainWindowView {
    private func getWindowSizeString() -> String {
        guard let window = manager.mainWindow else { return "未知" }
        return String(format: "%.0f × %.0f", window.frame.width, window.frame.height)
    }
}

extension baMainWindowView {
    private func getDebugWindowStatus() -> String {
        if manager.debugWindow?.parent != nil {
            return "已吸附"
        } else {
            return "已分离"
        }
    }
}
