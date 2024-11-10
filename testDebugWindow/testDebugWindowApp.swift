//
//  testDebugWindowApp.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    var debugWindow: NSWindow?
    weak var mainWindow: NSWindow?
    var isUserDraggingDebugWindow = false
    private let snapDistance: CGFloat = 20.0
    private var observers: [Any] = []
    private var isSetup = false

    // MARK: - Window Delegate Methods

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              !isDebugWindow(window) else { return }

        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            if isUserDraggingDebugWindow {
                let mainFrame = mainWindow?.frame ?? .zero
                let debugFrame = window.frame

                let xDistance = abs(debugFrame.minX - mainFrame.maxX)
                let yDistance = abs(debugFrame.minY - mainFrame.minY)

                if xDistance <= snapDistance && yDistance <= snapDistance {
                    DebugState.shared.isAttached = true
                    updateDebugWindowFrame()
                }
            }
        } else {
            handleMainWindowMove()
        }
    }

    func windowWillMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = true
        if DebugState.shared.isAttached {
            DebugState.shared.isAttached = false
        }
    }

    func windowDidEndMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = false
    }

    // MARK: - Private Methods

    private func isDebugWindow(_ window: NSWindow) -> Bool {
        return window.identifier?.rawValue == "debug-window"
    }

    private func handleDebugWindowMove(_ window: NSWindow) {
        guard let mainWindow = self.mainWindow,
              isUserDraggingDebugWindow else { return }

        let mainFrame = mainWindow.frame
        let debugFrame = window.frame

        let xDistance = abs(debugFrame.minX - mainFrame.maxX)
        let yDistance = abs(debugFrame.minY - mainFrame.minY)

        if xDistance <= snapDistance && yDistance <= snapDistance {
            DebugState.shared.isAttached = true
            updateDebugWindowFrame()
        }
    }

    private func handleMainWindowMove() {
        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }
    }

    private func handleMainWindowResize() {
        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }
    }

    private func updateDebugWindowFrame() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow,
              let screen = mainWindow.screen else { return }

        let mainFrame = mainWindow.frame
        let debugWidth = debugWindow.frame.width

        // 计算新的位置
        let newX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWidth)
        let newFrame = NSRect(
            x: newX,
            y: mainFrame.minY,
            width: debugWidth,
            height: mainFrame.height
        )

        // 应用新的位置
        debugWindow.setFrame(newFrame, display: true)

        // 确保窗口层级正确
        debugWindow.level = mainWindow.level

        print("Debug: Updated window frame - Main: \(mainFrame), Debug: \(newFrame)")
    }

    // MARK: - Public Methods

    func setupDebugWindow(with mainWindow: NSWindow) {
        guard !isSetup,
              let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) else { return }

        self.debugWindow = debugWindow
        self.mainWindow = mainWindow

        // 配置调试窗口
        debugWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        debugWindow.isMovable = true
        debugWindow.level = mainWindow.level

        // 设置窗口代理
        debugWindow.delegate = self
        mainWindow.delegate = self

        // 移除旧的观察者
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()

        // 添加吸附状态变化观察者
        let attachObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugWindowAttachStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let isAttached = notification.userInfo?["isAttached"] as? Bool else { return }

            if isAttached {
                self.updateDebugWindowFrame()
            }
        }
        observers.append(attachObserver)

        // 如果已经是吸附状态，立即更新位置
        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }

        isSetup = true
        print("Debug: Window delegate setup complete")

        // 设置窗口移动观察者
        setupWindowMoveObserver()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // 添加窗口移动通知观察
    private func setupWindowMoveObserver() {
        // 观察主窗口移动
        let mainWindowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: mainWindow,
            queue: .main
        ) { [weak self] _ in
            self?.handleMainWindowMove()
        }
        observers.append(mainWindowMoveObserver)

        // 观察主窗口大小变化
        let mainWindowResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: mainWindow,
            queue: .main
        ) { [weak self] _ in
            self?.handleMainWindowResize()
        }
        observers.append(mainWindowResizeObserver)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()
    private var setupComplete = false  // 添加标志

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保在合适的时机初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.trySetupDebugWindow(attempts: 0)
        }
    }

    private func trySetupDebugWindow(attempts: Int) {
        guard attempts < 10, !setupComplete else { return }  // 增加尝试次数，添加完成检查

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(attempts + 1)) {
            if let mainWindow = NSApplication.shared.windows.first(where: { !($0.identifier?.rawValue == "debug-window") }) {
                self.windowDelegate.setupDebugWindow(with: mainWindow)
                self.setupComplete = true
                print("Debug: Window setup complete")  // 添加日志
            } else {
                self.trySetupDebugWindow(attempts: attempts + 1)
            }
        }
    }
}

@main
struct testDebugWindowApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var debugState = DebugState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if let window = WindowAccessor.getWindow() {
                        window.center()
                        window.setFrameAutosaveName("Main Window")
                    }
                }
        }

        #if DEBUG
        Window("调试窗口", id: "debug-window") {
            DebugView()
                .environmentObject(debugState)
        }
        .defaultSize(width: 400, height: 300)
        .windowResizability(.contentSize)
        #endif
    }
}
