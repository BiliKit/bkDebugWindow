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
    @NSApplicationDelegateAdaptor private var appDelegate1: AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
         WindowGroup {
             MainWindowView(windowId: "MainWindow")
         }
//        WindowAnimationResizeGroup {
//            MainWindowView(windowId: "MainWindow")
//        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowMonitor: Any?
    var resizeObserver: NSObjectProtocol?
    let manager = WindowManager.shared

    let currentScreen = NSScreen.main ?? NSScreen.screens.first

    func applicationDidFinishLaunching(_ notification: Notification) {

        let debugWindow = initDebugWindow()

        let mainWindow = NSApplication.shared.windows.first

        // 设置窗口管理器
        manager.mainWindow = NSApplication.shared.windows.first
        manager.debugWindow = debugWindow

        // 配置两个窗口
        let windows = [NSApplication.shared.windows.first, debugWindow].compactMap { $0 }

        for (_, window) in windows.enumerated() {
            // 配置窗口
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)

            // 启用层支持
            window.contentView?.wantsLayer = true
            window.contentView?.layerContentsRedrawPolicy = .onSetNeedsDisplay

            // 设置窗口动画行为
            window.animationBehavior = .documentWindow
        }

        let mainWindowHeight = mainWindow?.frame.size.height
        let mainWindowMaxX = mainWindow?.frame.maxX
        let mainWindowMinY = mainWindow?.frame.minY

        // debugWindow.animator().setFrame(NSRect(x: mainWindowMaxX!, y: mainWindowMinY!, width: 120, height: mainWindowHeight!), display: true)
        // 串联动画
        animateWindow(debugWindow, to: NSRect(x: mainWindowMaxX!, y: mainWindowMinY!+(mainWindowHeight!-200), width: 120, height: 200), duration: 0) {
            self.animateWindow(debugWindow, to: NSRect(x: mainWindowMaxX!, y: mainWindowMinY!, width: 380, height: mainWindowHeight!), duration: 0.35, completion: nil)
        }

        mainWindow?.addChildWindow(debugWindow, ordered: .above)

        setupWindowDragAndSnapMonitor()
        setupWindowResizeSyncMonitor()

        // 显示调试窗口
        debugWindow.makeKeyAndOrderFront(nil)
        DebugState.shared.addMessage("调试窗口已显示", type: .info)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }
    @objc func handleWindowBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        DebugState.shared.addMessage(
            "窗口被激活",
            type: .info,
            details: """
                Identifier: \(window.identifier?.rawValue ?? "none")
                FileName: \((#file as NSString).lastPathComponent)
                FileID: \(#fileID)
                Function: \(#function)
                Line: \(#line)
            """)
    }

    func animateWindow(_ window: NSWindow, to frame: NSRect, duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup(
            {
                context in
                context.duration = duration
                window.animator().setFrame(frame, display: true)
            }, completionHandler: completion)
    }

    /// 关闭最后一个窗口后退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// 初始化调试窗口
    func initDebugWindow() -> NSWindow {

        let screenMaxX = currentScreen?.visibleFrame.maxX
        let screenMinY = currentScreen?.visibleFrame.minY

        let debugWindow = NSWindow(
            contentRect: NSRect(x: screenMaxX!, y: screenMinY!, width: 0, height: 0),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // 创建调试窗口
        debugWindow.contentView = NSHostingView(rootView: debugView(windowId: manager.debugWindowName))
        debugWindow.titlebarAppearsTransparent = true
        debugWindow.titleVisibility = .visible
        debugWindow.standardWindowButton(.closeButton)?.isHidden = true
        debugWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        debugWindow.standardWindowButton(.zoomButton)?.isHidden = true
        debugWindow.isMovableByWindowBackground = true
        debugWindow.title = manager.debugWindowName

        return debugWindow
    }

    /// 设置调试信息窗口拖拽和吸附监听器
    func setupWindowDragAndSnapMonitor() {
        windowMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { event in
            guard let debugWindow = self.manager.debugWindow,
                  //   let mainWindow = NSApplication.shared.windows.first,
                  let mainWindow = self.manager.mainWindow,
                  event.window == debugWindow else {
                return event
            }

            switch event.type {
            case .leftMouseDown:
                self.manager.dragStartLocation = debugWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                self.manager.stateBeforeDrag = self.manager.windowState

            case .leftMouseDragged:
                // 设置状态为拖动中
                self.manager.windowState = .dragging

                // 检查是否真的发生了拖动
                // let currentLocation = debugWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                // if let initialLocation = self.manager.initialClickLocation {
                    // 计算拖动距离
                    // let dragDistance = hypot(currentLocation.x - initialLocation.x,
                    //                        currentLocation.y - initialLocation.y)

                    // 如果是第一次确认拖动，解除子窗口关系
                    if debugWindow.parent != nil {
                        mainWindow.removeChildWindow(debugWindow)
                    }

                    // 检查吸附
                    /// debug window 的 frame
                    let frame = debugWindow.frame
                    /// main window 的 frame
                    let mainFrame = mainWindow.frame
                    /// 吸附距离
                    let snapDistance = self.manager.getEffectiveSnapDistance(for: frame, and: mainFrame)
                    /// 距离左边
                    let distanceToLeftEdge = abs(frame.maxX - mainFrame.minX)
                    /// 距离右边
                    let distanceToRightEdge = abs(frame.minX - mainFrame.maxX)
                    let hasVerticalOverlap = !(frame.maxY < mainFrame.minY || frame.minY > mainFrame.maxY)

                    self.manager.isReadyToSnap = (distanceToLeftEdge <= snapDistance || distanceToRightEdge <= snapDistance) && hasVerticalOverlap
                    DebugState.shared.updateWatchVariable(name: "isReadyToSnap", value: self.manager.isReadyToSnap, type: "Bool")

            case .leftMouseUp:
                // 重置初始点击位置
                self.manager.dragStartLocation = nil

                // 处理吸附逻辑（保持不变）
                if self.manager.isReadyToSnap {
                    /// debug window 的 frame
                    let frame = debugWindow.frame
                    /// main window 的 frame
                    let mainFrame = mainWindow.frame
                    /// 新的 frame
                    var newFrame = frame

                    // 判断应该吸附到哪一边
                    let snapDistance = self.manager.getEffectiveSnapDistance(for: frame, and: mainFrame)
                    let distanceToLeftEdge = abs(frame.maxX - mainFrame.minX)
                    let distanceToRightEdge = abs(frame.minX - mainFrame.maxX)

                    // 高度上有重叠
                    if distanceToLeftEdge <= snapDistance{
                        // 吸附到左边
                        newFrame.origin.x = mainFrame.minX - frame.width - 1
                        newFrame.origin.y = mainFrame.minY
                        newFrame.size.height = mainFrame.height
                    } else if distanceToRightEdge <= snapDistance {
                        // 吸附到右边
                        newFrame.origin.x = mainFrame.maxX + 1
                        newFrame.origin.y = mainFrame.minY
                        newFrame.size.height = mainFrame.height
                    }

                    // 执行吸附动画
                    NSAnimationContext.runAnimationGroup({ context in
                        context.duration = 0.2
                        debugWindow.animator().setFrame(newFrame, display: true)
                    }, completionHandler: {
                        mainWindow.addChildWindow(debugWindow, ordered: .above)
                    })
                    self.manager.windowState = .attached  // 吸附后更新状态
                } else {
                    if self.manager.windowState == .dragging {
                        self.manager.windowState = .detached
                    }
                    if self.manager.stateBeforeDrag == .detached {
                        self.manager.windowState = .detached
                    }
                }
                // 重置初始点击位置
                self.manager.dragStartLocation = nil
                self.manager.stateBeforeDrag = nil
                self.manager.isReadyToSnap = false

            default:
                break
            }

            return event
        }
    }

    func setupWindowResizeSyncMonitor() {
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: manager.mainWindow,
            queue: .main
        ) { [weak self] notification in
            guard let mainWindow = notification.object as? NSWindow,
                  let debugWindow = self?.manager.debugWindow,
                  debugWindow.parent != nil else { return }

            var newFrame = debugWindow.frame
            newFrame.size.height = mainWindow.frame.height

            // 判断 debugWindow 在主窗口的哪一侧
            if debugWindow.frame.minX < mainWindow.frame.minX {
                // debugWindow 在左侧
                newFrame.origin.x = mainWindow.frame.minX - debugWindow.frame.width - 1
            } else {
                // debugWindow 在右侧
                newFrame.origin.x = mainWindow.frame.maxX + 1
            }
            newFrame.origin.y = mainWindow.frame.minY

            if self?.manager.windowMode == .animation {
                // 使用动画调整位置和大小
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    context.timingFunction = CAMediaTimingFunction(name: .linear)
                    debugWindow.animator().setFrame(newFrame, display: true)
                }
            } else {
                // 直接设置 frame，不使用动画
                debugWindow.setFrame(newFrame, display: true)
            }
        }
    }

    deinit {
        // 移除监听器
        if let monitor = windowMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // 移除大小变化观察者
        if let observer = resizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
//class WindowDelegate: NSObject, NSWindowDelegate {
//    var debugWindow: NSWindow?                      // 调试窗口
//    weak var mainWindow: NSWindow?                  // 主窗口
//    var isUserDraggingDebugWindow: Bool = false     // 是否正在拖拽调试窗口
//    private let snapDistance: CGFloat = 20.0        // 吸附距离
//    private var observers: [Any] = []               // 观察者列表
//    private var isSetup: Bool = false               // 是否已设置
//    private var debugState: DebugState = .shared
//
//    // 添加对 Environment 变量的引用
//    private var openWindow: OpenWindowAction?
//    private var dismissWindow: DismissWindowAction?
//
//    // 添加标志来区分是否是程序控制的移动
//    private var isProgrammaticMove = false
//
//    func setupDebugWindow(with mainWindow: NSWindow) {
//
//        setupWindowMoveObserver()
//
//
//        if debugState.isAttached {
//            makeDebugWindowChild(of: mainWindow)
//        }
//    }
//
//    /// 处理主窗口移动
//    private func handleMainWindowMove() {
//        debugState.system("Handling main window move")
//        if debugState.isAttached && debugWindow?.parent == nil {
//        }
//    }
//
//    /// 设置窗口移动观察者
//    private func setupWindowMoveObserver() {
//        // 移除旧的观察者
//        observers.forEach { NotificationCenter.default.removeObserver($0) }
//        observers.removeAll()
//
//        debugState.system("Setting up window move observers")
//
//        // 观察主窗口移动
//        let mainWindowMoveObserver = NotificationCenter.default.addObserver(
//            forName: NSWindow.didMoveNotification,
//            object: mainWindow,
//            queue: .main
//        ) { [weak self] _ in
//            self?.handleMainWindowMove()
//        }
//        observers.append(mainWindowMoveObserver)
//
//        // 修改 windowDidEndLiveResize 方法中的观察者
//        let mainWindowResizeObserver = NotificationCenter.default.addObserver(
//            forName: NSWindow.didResizeNotification,
//            object: mainWindow,
//            queue: .main
//        ) { [weak self] _ in
//            if DebugState.shared.isAttached {
//            }
//        }
//        observers.append(mainWindowResizeObserver)
//    }
//
//    func makeDebugWindowChild(of mainWindow: NSWindow) {
//        guard let debugWindow = debugWindow else { return }
//
//        debugState.system("Making debug window child")
//
//        // 先更新位置，再设置子窗口关系
//        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
//        debugWindow.setFrame(targetFrame, display: true)
//
//        // 移除之前的子窗口关系
//        mainWindow.removeChildWindow(debugWindow)
//
//        // 设置为子窗口
//        mainWindow.addChildWindow(debugWindow, ordered: .above)
//
//        // 确保更新状态
//        debugState.isAttached = true
//
//        debugState.system("Debug window set as child window",
//            details: """
//            Parent window: \(mainWindow)
//            Child window: \(debugWindow)
//            Frame: \(debugWindow.frame)
//            Is child window: \(debugWindow.parent != nil)
//            """)
//    }
//
//    // MARK: - Debug Window Methods
//
//    internal func toggleDebugWindow() {
//        if debugState.isWindowOpen {
//            if let mainWindow = mainWindow,
//               let debugWindow = debugWindow {
//                mainWindow.removeChildWindow(debugWindow)
//            }
//            dismissWindow?(id: "debug-window")
//            debugState.isWindowOpen = false
//        } else {
//            openWindow?(id: "debug-window")
//            debugState.isWindowOpen = true
//            // 给窗口一点时间创建
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                if let mainWindow = self.mainWindow,
//                   let debugWindow = self.debugWindow {
//                    if self.debugState.isAttached {
//                        self.makeDebugWindowChild(of: mainWindow)
//                    }
//                }
//            }
//        }
//    }
//
//    // 添加新方法用于计算目标位置
//    private func calculateDebugWindowFrame(mainWindow: NSWindow, debugWindow: NSWindow) -> NSRect {
//        let mainFrame = mainWindow.frame
//        let debugWidth = debugWindow.frame.width
//        let screen = mainWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
//
//        // 确保不会超出屏幕
//        let newX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWidth)
//
//        return NSRect(
//            x: newX,
//            y: mainFrame.minY,
//            width: debugWidth,
//            height: mainFrame.height
//        )
//    }
//
//    private var windowAnimator: WindowAnimator?
//
//    // 修改 resetDebugWindow 方法
//    func resetDebugWindow() {
//        guard let mainWindow = mainWindow,
//              let debugWindow = debugWindow else {
//            debugState.error("Failed to reset: windows not available")
//            return
//        }
//
//        debugState.system("Reset debug window initiated")
//
//        // 设置为程序控制的移动
//        isProgrammaticMove = true
//
//        // 确保移除子窗口关系以便动画
//        mainWindow.removeChildWindow(debugWindow)
//
//        // 计算目标位置
//        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
//
//        // 创建动画器并执行动画
//        windowAnimator = WindowAnimator(window: debugWindow)
//        windowAnimator?.animate(to: targetFrame) { [weak self] in
//            guard let self = self else { return }
//
//            // 动画完成后的处理
//            DispatchQueue.main.async {
//                self.isProgrammaticMove = false  // 重置标志
//                self.debugState.isAttached = true
//
//                // 确保设置子窗口关系
//                if self.debugState.isAttached {
//                    self.makeDebugWindowChild(of: mainWindow)
//                }
//
//                self.debugState.system("Animation completed and child window relationship established")
//            }
//        }
//    }
//}
