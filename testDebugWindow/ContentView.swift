//
//  ContentView.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI

/// 主窗口内容视图
struct ContentView: View {
    // MARK: - 属性

    /// 计数器状态
    @State private var counter = 0
    /// 窗口操作环境变量
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    /// 调试状态对象
    @StateObject private var debugState = DebugState.shared

    // MARK: - 计时器相关
    @State private var timer: Timer?
    @State private var isAutoGeneratingLogs = false

    // MARK: - 视图构建

    var body: some View {
        VStack(spacing: 20) {
            // 计数器显示
            Text("计数器: \(counter)")
                .font(.title)

            // 测试按钮组
            buttonsGroup

            // 调试窗口控制
            #if DEBUG
            debugWindowControl
            #endif
        }
        .padding()
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            stopAutoGenerateLogs()
        }
    }

    // MARK: - 子视图

    /// 按钮组视图
    private var buttonsGroup: some View {
        VStack(spacing: 15) {
            // 增加计数按钮
            Button("增加计数") {
                incrementCounter()
            }

            // 测试事件按钮
            Button("触发测试事件") {
                generateTestEvents()
            }

            // 自动生成日志按钮
            Button(isAutoGeneratingLogs ? "停止自动生成日志" : "开始自动生成日志") {
                isAutoGeneratingLogs.toggle()
                if isAutoGeneratingLogs {
                    startAutoGenerateLogs()
                } else {
                    stopAutoGenerateLogs()
                }
            }
            .foregroundColor(isAutoGeneratingLogs ? .red : .blue)
        }
    }

    /// 调试窗口控制视图
    private var debugWindowControl: some View {
        Button(debugState.isWindowOpen ? "关闭调试窗口" : "打开调试窗口") {
            toggleDebugWindow()
        }
    }

    // MARK: - 私有方法

    /// 设置初始状态
    private func setupInitialState() {
        #if DEBUG
        debugState.addMessage("主窗口已加载", type: .info)
        // 确保按钮状态与窗口状态同步
        debugState.isWindowOpen = NSApplication.shared.windows.contains {
            $0.identifier?.rawValue == "debug-window" && $0.isVisible
        }
        #endif
    }

    /// 增加计数器
    private func incrementCounter() {
        counter += 1
        #if DEBUG
        debugState.addMessage(
            "计数器增加到: \(counter)",
            type: .userAction,
            details: "Button tapped at \(Date())"
        )
        #endif
    }

    /// 生成测试事件
    private func generateTestEvents() {
        #if DEBUG
        // 网络请求模拟
        debugState.addMessage(
            "开始网络请求",
            type: .network,
            details: "GET https://api.example.com/data"
        )

        // 性能监控
        debugState.addMessage(
            "内存使用: \(Int.random(in: 100...500))MB",
            type: .performance,
            details: "CPU: \(Int.random(in: 1...10))%, GPU: \(Int.random(in: 1...5))%"
        )

        // 系统事件
        debugState.addMessage(
            "系统配置已更新",
            type: .system,
            details: "Theme: Dark, Language: zh-CN"
        )
        #endif
    }

    /// 切换调试窗口显示状态
    private func toggleDebugWindow() {
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

    /// 开始自动生成日志
    private func startAutoGenerateLogs() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let types: [DebugMessageType] = [.info, .warning, .error, .network, .performance, .system]
            let randomType = types.randomElement() ?? .info

            debugState.addMessage(
                "自动生成的测试消息 #\(Int.random(in: 1000...9999))",
                type: randomType,
                details: "Generated at \(Date())"
            )
        }
    }

    /// 停止自动生成日志
    private func stopAutoGenerateLogs() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 预览
#Preview {
    ContentView()
}
