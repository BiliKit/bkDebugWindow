//
//  testDebugWindowApp.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-10.
//

import SwiftUI
import AppKit

class WindowDelegate: NSObject, NSWindowDelegate {
    var debugWindow: NSWindow?                      // 调试窗口
    weak var mainWindow: NSWindow?                  // 主窗口
    var isUserDraggingDebugWindow = false           // 是否正在拖拽调试窗口
    private let snapDistance: CGFloat = 20.0         // 吸附距离
    private var observers: [Any] = []               // 观察者列表
    private var isSetup = false                 // 是否已设置
    private var debugState: DebugState {
        return DebugState.shared
    }

    // 添加对 Environment 变量的引用
    private var openWindow: OpenWindowAction?
    private var dismissWindow: DismissWindowAction?

    // 添加初始化方法来设置 Environment actions
    func setEnvironmentActions(open: OpenWindowAction?, dismiss: DismissWindowAction?) {
        self.openWindow = open
        self.dismissWindow = dismiss
    }

    // 添加标志来区分是否是程序控制的移动
    private var isProgrammaticMove = false

    // MARK: - Window Delegate Methods

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            DebugState.shared.system("调试窗口大小改变",
                details: "新大小: \(window.frame.size)")
        } else {
            DebugState.shared.system("主窗口大小改变",
                details: "新大小: \(window.frame.size)")

            if DebugState.shared.isAttached {
                updateDebugWindowFrame()
            }
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            debugState.system("Debug window moved",
                details: """
                Position: \(window.frame.origin)
                Is dragging: \(isUserDraggingDebugWindow)
                Is attached: \(debugState.isAttached)
                """)

            if isUserDraggingDebugWindow {
                let mainFrame = mainWindow?.frame ?? .zero
                let debugFrame = window.frame

                let xDistance = abs(debugFrame.minX - mainFrame.maxX)
                let yDistance = abs(debugFrame.minY - mainFrame.minY)

                debugState.system("Checking snap distance",
                    details: """
                    X distance: \(xDistance)
                    Y distance: \(yDistance)
                    Snap threshold: \(snapDistance)
                    """)

                if xDistance <= snapDistance && yDistance <= snapDistance {
                    isProgrammaticMove = true
                    debugState.isAttached = true

                    // 先重置窗口位置
                    resetDebugWindow()

                    // 确保设置子窗口关系
                    if let mainWindow = self.mainWindow {
                        makeDebugWindowChild(of: mainWindow)
                    }

                    debugState.system("Window snapped and child relationship established")
                }
            }
        } else {
            debugState.system("Main window moved",
                details: "New position: \(window.frame.origin)")

            // 如果调试窗口已吸附，更新其位置
            if debugState.isAttached {
                // 确保是主窗口移动而不是程序控制的移动
                if !isProgrammaticMove {
                    if let debugWindow = debugWindow {
                        // 如果不是子窗口，需要手动更新位置
                        if debugWindow.parent == nil {
                            updateDebugWindowFrame()
                        }
                    }
                }
            }
        }

        // 更新窗口位置状态
        debugState.updateWindowState(
            position: window.frame.origin,
            size: window.frame.size
        )
    }

    func windowWillMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        // 如果是程序控制的移动，不处理
        if isProgrammaticMove {
            return
        }

        isUserDraggingDebugWindow = true
        debugState.system("Debug window will move",
            details: """
            Current position: \(window.frame.origin)
            Previous attach state: \(debugState.isAttached)
            Is programmatic: \(isProgrammaticMove)
            """)

        // 更新拖拽状态监视
        debugState.updateWatchVariable(
            name: "isDragging",
            value: true,
            type: "Window"
        )

        if debugState.isAttached {
            debugState.isAttached = false
            mainWindow?.removeChildWindow(window)
        }
    }

    // func windowDidEndMove(_ notification: Notification) {
    //     guard let window = notification.object as? NSWindow,
    //           isDebugWindow(window) else { return }

    //     isUserDraggingDebugWindow = false
    //     DebugState.shared.system("Debug window ended move",
    //         details: """
    //         Final position: \(window.frame.origin)
    //         Is attached: \(DebugState.shared.isAttached)
    //         """)
    // }

    func windowDidEndSheet(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = false
        debugState.system("Debug window ended move",
            details: """
            Final position: \(window.frame.origin)
            Is attached: \(debugState.isAttached)
            """)

        // 更新拖拽状态监视
        debugState.updateWatchVariable(
            name: "isDragging",
            value: false,
            type: "Window"
        )
    }

    // 修改 windowDidEndLiveResize 方法
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }

        isUserDraggingDebugWindow = false
        debugState.system("Debug window ended resize",
            details: "Final size: \(window.frame.size)")
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

        if debugState.isAttached {
            makeDebugWindowChild(of: mainWindow)
        }
    }

    private func updateDebugWindowFrame() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow else { return }

        // 如果已经是子窗口，不需要手动更新位置
        if debugWindow.parent != nil {
            return
        }

        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)

        // 使用动画器来更新位置
        windowAnimator = WindowAnimator(window: debugWindow)
        windowAnimator?.animate(to: targetFrame) { [weak self] in
            guard let self = self else { return }
            if self.debugState.isAttached {
                self.makeDebugWindowChild(of: mainWindow)
            }
        }
    }

    // MARK: - 辅助方法

    /// 检查是否为调试窗口
    private func isDebugWindow(_ window: NSWindow) -> Bool {
        return window.identifier?.rawValue == "debug-window"
    }

    /// 处理主窗口移动
    private func handleMainWindowMove() {
        debugState.system("Handling main window move")
        if debugState.isAttached && debugWindow?.parent == nil {
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

        // 修改 windowDidEndLiveResize 方法中的观察者
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

    // MARK: - Child Window Methods

    func makeDebugWindowChild(of mainWindow: NSWindow) {
        guard let debugWindow = debugWindow else { return }

        debugState.system("Making debug window child")

        // 先更新位置，再设置子窗口关系
        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
        debugWindow.setFrame(targetFrame, display: true)

        // 移除之前的子窗口关系
        mainWindow.removeChildWindow(debugWindow)

        // 设置为子窗口
        mainWindow.addChildWindow(debugWindow, ordered: .above)

        // 确保更新状态
        debugState.isAttached = true

        debugState.system("Debug window set as child window",
            details: """
            Parent window: \(mainWindow)
            Child window: \(debugWindow)
            Frame: \(debugWindow.frame)
            Is child window: \(debugWindow.parent != nil)
            """)
    }

    // MARK: - Debug Window Methods

    internal func toggleDebugWindow() {
        if debugState.isWindowOpen {
            if let mainWindow = mainWindow,
               let debugWindow = debugWindow {
                mainWindow.removeChildWindow(debugWindow)
            }
            dismissWindow?(id: "debug-window")
            debugState.isWindowOpen = false
        } else {
            openWindow?(id: "debug-window")
            debugState.isWindowOpen = true
            // 给窗口一点时间创建
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let mainWindow = self.mainWindow,
                   let debugWindow = self.debugWindow {
                    if self.debugState.isAttached {
                        self.makeDebugWindowChild(of: mainWindow)
                    }
                }
            }
        }
    }

    // 添加新方法用于计算目标位置
    private func calculateDebugWindowFrame(mainWindow: NSWindow, debugWindow: NSWindow) -> NSRect {
        let mainFrame = mainWindow.frame
        let debugWidth = debugWindow.frame.width
        let screen = mainWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!

        // 确保不会超出屏幕
        let newX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWidth)

        return NSRect(
            x: newX,
            y: mainFrame.minY,
            width: debugWidth,
            height: mainFrame.height
        )
    }

    private var windowAnimator: WindowAnimator?

    // 修改 resetDebugWindow 方法
    func resetDebugWindow() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow else {
            debugState.error("Failed to reset: windows not available")
            return
        }

        debugState.system("Reset debug window initiated")

        // 设置为程序控制的移动
        isProgrammaticMove = true

        // 确保移除子窗口关系以便动画
        mainWindow.removeChildWindow(debugWindow)

        // 计算目标位置
        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)

        // 创建动画器并执行动画
        windowAnimator = WindowAnimator(window: debugWindow)
        windowAnimator?.animate(to: targetFrame) { [weak self] in
            guard let self = self else { return }

            // 动画完成后的处理
            DispatchQueue.main.async {
                self.isProgrammaticMove = false  // 重置标志
                self.debugState.isAttached = true

                // 确保设置子窗口关系
                if self.debugState.isAttached {
                    self.makeDebugWindowChild(of: mainWindow)
                }

                self.debugState.system("Animation completed and child window relationship established")
            }
        }
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
    var statusItem: NSStatusItem?
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

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button: NSStatusBarButton = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group.fill", accessibilityDescription: "Space Saver")
            button.action = #selector(statusBarButtonClicked)
        }
    }

    @objc func statusBarButtonClicked() {
        let contentView = ContentView()
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 600, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.show(
            relativeTo: statusItem!.button!.bounds, of: statusItem!.button!,
            preferredEdge: NSRectEdge.minY)

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
