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
    @ObservedObject var debugState: DebugState = .shared

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
            setupWindowChangeObserver()
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

        // 基础状态监视
        debugState.updateWatchVariable(
            name: "counter",
            value: counter,
            type: "Int"
        )
        debugState.updateWatchVariable(
            name: "isAutoGeneratingLogs",
            value: isAutoGeneratingLogs,
            type: "Bool"
        )

        // 窗口状态监视
        debugState.updateWatchVariable(
            name: "activeWindow",
            value: NSApplication.shared.mainWindow?.title ?? "none",
            type: "Window"
        )
        debugState.updateWatchVariable(
            name: "isAttached",
            value: debugState.isAttached,
            type: "Window"
        )
        debugState.updateWatchVariable(
            name: "isDragging",
            value: (NSApplication.shared.delegate as? AppDelegate)?.windowDelegate.isUserDraggingDebugWindow ?? false,
            type: "Window"
        )
        debugState.updateWatchVariable(
            name: "isWindowOpen",
            value: debugState.isWindowOpen,
            type: "Window"
        )

        // 添加窗口状态观察者
        observeActiveWindow()
        observeAttachState()
        observeDraggingState()
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
        // 更新监视变量
        debugState.updateWatchVariable(
            name: "counter",
            value: counter,
            type: "Int"
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

        // 结束事件
        debugState.addMessage("这是一条错误信息", type: .error)

        // 结束事件
        debugState.addMessage("这是一条警告信息", type: .warning)

        // 结束事件
        debugState.addMessage("这是一条信息信息", type: .info)

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
        }

        #if DEBUG
        // 更新窗口状态监视
        debugState.updateWatchVariable(
            name: "isWindowOpen",
            value: debugState.isWindowOpen,
            type: "Bool"
        )
        #endif
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

        isAutoGeneratingLogs = true
        #if DEBUG
        // 更新监视变量
        debugState.updateWatchVariable(
            name: "isAutoGeneratingLogs",
            value: isAutoGeneratingLogs,
            type: "Bool"
        )
        #endif
    }

    /// 停止自动生成日志
    private func stopAutoGenerateLogs() {
        timer?.invalidate()
        timer = nil
        isAutoGeneratingLogs = false
        #if DEBUG
        // 更新监视变量
        debugState.updateWatchVariable(
            name: "isAutoGeneratingLogs",
            value: isAutoGeneratingLogs,
            type: "Bool"
        )
        #endif
    }

    /// 观察当前激活的窗口
    private func observeActiveWindow() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow {
                debugState.updateWatchVariable(
                    name: "activeWindow",
                    value: window.title,
                    type: "Window"
                )
            }
        }
    }

    // 添加拖拽状态观察方法
    private func observeDraggingState() {
        let debugState = self.debugState // 捕获 debugState

        NotificationCenter.default.addObserver(
            forName: NSWindow.willMoveNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.identifier?.rawValue == "debug-window" {
                debugState.updateWatchVariable(
                    name: "isDragging",
                    value: true,
                    type: "Window"
                )
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let window = notification.object as? NSWindow,
               window.identifier?.rawValue == "debug-window" {
                debugState.updateWatchVariable(
                    name: "isDragging",
                    value: false,
                    type: "Window"
                )
            }
        }
    }
}

extension ContentView {
    /// 设置主窗口状态监听
    func setupWindowChangeObserver() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: nil) { notification in
            debugState.addMessage("主窗口状态改变", type: .info, details: "\(notification.object)")
        }

        notificationCenter.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: nil) { notification in
            debugState.addMessage("主窗口移动: \(String(describing: notification.object))", type: .info)
        }
    }
}

// 添加对窗口吸附状态的监听
extension ContentView {
    private func observeAttachState() {
        let debugState = self.debugState // 捕获 debugState

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugWindowAttachStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            guard let isAttached = notification.userInfo?["isAttached"] as? Bool else { return }
            debugState.updateWatchVariable(
                name: "isAttached",
                value: isAttached,
                type: "Window"
            )
        }
    }
}

// MARK: - 预览
#Preview {
    ContentView()
}
