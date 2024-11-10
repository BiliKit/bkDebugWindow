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
    private var debugState: DebugState {
        return DebugState.shared
    }

    // MARK: - Window Delegate Methods

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            DebugState.shared.system("Debug window resized",
                details: "New size: \(window.frame.size)")
        } else {
            DebugState.shared.system("Main window resized",
                details: "New size: \(window.frame.size)")

            if DebugState.shared.isAttached {
                updateDebugWindowFrame()
            }
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            DebugState.shared.system("Debug window moved",
                details: """
                Position: \(window.frame.origin)
                Is dragging: \(isUserDraggingDebugWindow)
                Is attached: \(DebugState.shared.isAttached)
                """)

            if isUserDraggingDebugWindow {
                let mainFrame = mainWindow?.frame ?? .zero
                let debugFrame = window.frame

                let xDistance = abs(debugFrame.minX - mainFrame.maxX)
                let yDistance = abs(debugFrame.minY - mainFrame.minY)

                DebugState.shared.system("Checking snap distance",
                    details: """
                    X distance: \(xDistance)
                    Y distance: \(yDistance)
                    Snap threshold: \(snapDistance)
                    """)

                if xDistance <= snapDistance && yDistance <= snapDistance {
                    DebugState.shared.isAttached = true
                    updateDebugWindowFrame()
                }
            }
        } else {
            DebugState.shared.system("Main window moved",
                details: "New position: \(window.frame.origin)")
            handleMainWindowMove()
        }
    }

    func windowWillMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = true
        DebugState.shared.system("Debug window will move",
            details: """
            Current position: \(window.frame.origin)
            Previous attach state: \(DebugState.shared.isAttached)
            """)

        if DebugState.shared.isAttached {
            DebugState.shared.isAttached = false
        }
    }

    func windowDidEndMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = false
        DebugState.shared.system("Debug window ended move",
            details: """
            Final position: \(window.frame.origin)
            Is attached: \(DebugState.shared.isAttached)
            """)
    }

    // MARK: - Setup Methods

    func setupDebugWindow(with mainWindow: NSWindow) {
        guard !isSetup else {
            DebugState.shared.warning("Attempted to setup debug window when already setup")
            return
        }

        DebugState.shared.system("Setting up debug window",
            details: """
            Main window: \(mainWindow)
            Current windows count: \(NSApplication.shared.windows.count)
            """)

        guard let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) else {
            DebugState.shared.error("Failed to find debug window")
            return
        }

        self.debugWindow = debugWindow
        self.mainWindow = mainWindow

        DebugState.shared.system("Configuring debug window",
            details: """
            Debug window: \(debugWindow)
            Collection behavior: \(debugWindow.collectionBehavior.rawValue)
            Is movable: \(debugWindow.isMovable)
            Window level: \(debugWindow.level.rawValue)
            """)

        // 配置调试窗口
        debugWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        debugWindow.isMovable = true
        debugWindow.level = mainWindow.level

        // 设置窗口代理
        debugWindow.delegate = self
        mainWindow.delegate = self

        setupWindowMoveObserver()

        isSetup = true
        DebugState.shared.system("Debug window setup complete",
            details: """
            Main window frame: \(mainWindow.frame)
            Debug window frame: \(debugWindow.frame)
            Is attached: \(DebugState.shared.isAttached)
            """)

        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }
    }

    private func updateDebugWindowFrame() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow,
              let screen = mainWindow.screen else {
            DebugState.shared.error("Failed to update debug window frame",
                details: """
                Main window: \(String(describing: mainWindow))
                Debug window: \(String(describing: debugWindow))
                Screen: \(String(describing: mainWindow?.screen))
                """)
            return
        }

        let mainFrame = mainWindow.frame
        let debugWidth = debugWindow.frame.width
        let newX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWidth)
        let newFrame = NSRect(
            x: newX,
            y: mainFrame.minY,
            width: debugWidth,
            height: mainFrame.height
        )

        DebugState.shared.system("Updating debug window frame",
            details: """
            Previous frame: \(debugWindow.frame)
            New frame: \(newFrame)
            Screen visible frame: \(screen.visibleFrame)
            """)

        debugWindow.setFrame(newFrame, display: true)
        debugWindow.level = mainWindow.level
    }

    // MARK: - 辅助方法

    /// 检查是否为调试窗口
    private func isDebugWindow(_ window: NSWindow) -> Bool {
        return window.identifier?.rawValue == "debug-window"
    }

    /// 处理主窗口移动
    private func handleMainWindowMove() {
        debugState.system("Handling main window move")
        if DebugState.shared.isAttached {
            updateDebugWindowFrame()
        }
    }

    /// 设置窗口移动观察者
    private func setupWindowMoveObserver() {
        // 移除旧的观察者
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()

        debugState.system("Setting up window move observers")

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
            if DebugState.shared.isAttached {
                self?.updateDebugWindowFrame()
            }
        }
        observers.append(mainWindowResizeObserver)

        debugState.system("Window move observers setup complete",
            details: "Added observers for move and resize events")
    }

    // MARK: - 清理方法

    deinit {
        debugState.system("WindowDelegate deinitializing")
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

@main
struct testDebugWindowApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.debugState)
        }

        #if DEBUG
        Window("调试窗口", id: "debug-window") {
            DebugView()
                .environmentObject(appDelegate.debugState)
        }
        .defaultSize(width: 400, height: 300)
        .windowResizability(.contentSize)
        #endif
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()
    private var setupComplete = false
    let debugState: DebugState

    // 添加窗口设置重试计时器
    private var setupTimer: Timer?

    override init() {
        self.debugState = DebugState.shared
        super.init()
        debugState.system("AppDelegate initialized", details: "DebugState instance created")

        // 修改为正确的通知名称
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDebugStateReset),
            name: NSNotification.Name("ResetDebugState"),
            object: nil
        )
        debugState.system("Observers registered")
    }

    // 修改处理方法名称和实现
    @objc private func handleWindowBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        debugState.system("Window became key",
            details: "Identifier: \(window.identifier?.rawValue ?? "none")")

        // 如果是调试窗口被激活，重新尝试设置
        if window.identifier?.rawValue == "debug-window" {
            debugState.system("Debug window became key, attempting setup")
            trySetupDebugWindow(attempts: 0)
        }
    }

    @objc private func handleDebugStateReset() {
        debugState.system("Reset notification received", details: "Initiating state reset")
        DispatchQueue.main.async {
            self.debugState.reset()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        debugState.system("Application did finish launching")
        NotificationCenter.default.post(name: NSNotification.Name("AppDidFinishLaunching"), object: nil)

        // 启动定期检查计时器
        setupTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndSetupWindows()
        }
    }

    private func checkAndSetupWindows() {
        guard !setupComplete else {
            setupTimer?.invalidate()
            setupTimer = nil
            return
        }

        debugState.system("Checking windows",
            details: "Window count: \(NSApplication.shared.windows.count)")

        let mainWindow = NSApplication.shared.windows.first(where: { !($0.identifier?.rawValue == "debug-window") })
        let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" })

        if let mainWindow = mainWindow, let debugWindow = debugWindow {
            debugState.system("Both windows found, setting up")
            windowDelegate.setupDebugWindow(with: mainWindow)
            setupComplete = true
            setupTimer?.invalidate()
            setupTimer = nil
        }
    }

    private func trySetupDebugWindow(attempts: Int) {
        guard attempts < 10, !setupComplete else {
            if attempts >= 10 {
                debugState.error("Window setup failed", details: "Maximum attempts reached")
            }
            return
        }

        debugState.system("Attempting window setup", details: "Attempt \(attempts + 1) of 10")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(attempts + 1)) {
            if let mainWindow = NSApplication.shared.windows.first(where: { !($0.identifier?.rawValue == "debug-window") }) {
                if let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) {
                    self.windowDelegate.setupDebugWindow(with: mainWindow)
                    self.setupComplete = true
                    self.debugState.system("Window setup complete")
                } else {
                    self.debugState.warning("Debug window not found", details: "Retrying...")
                    self.trySetupDebugWindow(attempts: attempts + 1)
                }
            } else {
                self.debugState.warning("Main window not found", details: "Retrying...")
                self.trySetupDebugWindow(attempts: attempts + 1)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugState.system("Application will terminate")
    }

    deinit {
        setupTimer?.invalidate()
        setupTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
}
