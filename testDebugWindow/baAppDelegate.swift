//
//  baAppDelegate.swift
//  testDebugWindow
//
//  Created by Iris on 2024-11-15.
//

import SwiftUI

class baAppDelegate: NSObject, NSApplicationDelegate {
    var windowMonitor: Any?
    var resizeObserver: NSObjectProtocol?
    let manager = baWindowManager.shared

    let currentScreen = NSScreen.main ?? NSScreen.screens.first

    func applicationDidFinishLaunching(_ notification: Notification) {

        let debugWindow = baDebugWindowDelegate.shared.createDebugWindow()

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

        let mainWindowHeight = manager.mainWindow?.frame.size.height
        let mainWindowMaxX = manager.mainWindow?.frame.maxX
        let mainWindowMinY = manager.mainWindow?.frame.minY

        let startFrame = NSRect(x: mainWindowMaxX!,
            y: mainWindowMinY!+(mainWindowHeight!-200),
            width: manager.defaultDebugWindowWidth,
            height: 200)

        let endFrame = NSRect(
            x: mainWindowMaxX!,
            y: mainWindowMinY!,
            width: manager.defaultDebugWindowWidth,
            height: mainWindowHeight!)

        animateWindow(debugWindow, to: startFrame, duration: 0.0) {}
        animateWindow(debugWindow, to: endFrame, duration: 0.45) {}

        manager.mainWindow?.addChildWindow(debugWindow, ordered: .above)
        #if DEVELOPMENT
        DebugState.shared.system("debugWindow 已绑定为 mainWindow 子窗口")
        #endif

        setupWindowDragAndSnapMonitor()
        setupWindowResizeSyncMonitor()

        // 显示调试窗口
        debugWindow.makeKeyAndOrderFront(nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }
    @objc func handleWindowBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        manager.activeWindow = window
        #if DEVELOPMENT
        if window == manager.debugWindow {
            DebugState.shared.system("debug window 被激活", details: """
                Identifier: \(window.identifier?.rawValue ?? "none")
                FileName: \((#file as NSString).lastPathComponent)
                FileID: \(#fileID)
                Function: \(#function)
                Line: \(#line)
                """)
        }
        #endif
    }

    func animateWindow(_ window: NSWindow, to frame: NSRect, duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup(
            {
                context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }, completionHandler: completion)
    }

    /// 关闭最后一个窗口后退出
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// 初始化调试窗口
    ///
    /// 调试窗口的初始化配置:
    /// - 位置: 屏幕最右侧
    /// - 高度: 与主窗口相同
    /// - 界面元素:
    ///   - 隐藏标题栏
    ///   - 隐藏关闭按钮
    ///   - 隐藏最小化按钮
    ///   - 隐藏缩放按钮
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
        debugWindow.identifier = NSUserInterfaceItemIdentifier(rawValue: manager.debugWindowName)

        return debugWindow
    }

    /// 设置调试信息窗口拖拽和吸附监听器
    func setupWindowDragAndSnapMonitor() {
        // 监听调试窗口的拖拽
        windowMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self = self,
                  let debugWindow = self.manager.debugWindow,
                  let mainWindow = self.manager.mainWindow,
                  event.window == debugWindow else {
                return event
            }

            return self.handleDebugWindowDrag(event, debugWindow: debugWindow, mainWindow: mainWindow)
        }

        // 监听主窗口的拖拽
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMainWindowMove(_:)),
            name: NSWindow.didMoveNotification,
            object: manager.mainWindow
        )
    }

    /// 处理调试窗口的拖拽事件
    private func handleDebugWindowDrag(_ event: NSEvent, debugWindow: NSWindow, mainWindow: NSWindow) -> NSEvent {
        switch event.type {
        case .leftMouseDown:
            // 记录拖动开始位置和状态
            manager.dragStartLocation = debugWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
            manager.stateBeforeDrag = manager.windowState

        case .leftMouseDragged:
            // 设置状态为拖动中
            manager.windowState = .dragging

            // 如果是激活的调试窗口被拖动，解除子窗口关系
            if debugWindow.parent != nil && manager.activeWindow == debugWindow {
                mainWindow.removeChildWindow(debugWindow)
                #if DEVELOPMENT
                DebugState.shared.system("解除子窗口关系")
                #endif
            }

            // 检查吸附
            /// debug window 的 frame
            let frame = debugWindow.frame
            /// main window 的 frame
            let mainFrame = mainWindow.frame
            let snapDistance = manager.getEffectiveSnapDistance(for: frame, and: mainFrame)
            let distanceToLeftEdge = abs(frame.maxX - mainFrame.minX)
            let distanceToRightEdge = abs(frame.minX - mainFrame.maxX)
            let hasVerticalOverlap = !(frame.maxY < mainFrame.minY || frame.minY > mainFrame.maxY)

            // 更新吸附状态
            manager.isReadyToSnap = (distanceToLeftEdge <= snapDistance || distanceToRightEdge <= snapDistance) && hasVerticalOverlap

        case .leftMouseUp:
            // 重置拖动状态
            manager.dragStartLocation = nil

            // 处理吸附
            if manager.isReadyToSnap {
                handleDebugWindowSnap(debugWindow: debugWindow, mainWindow: mainWindow)
            } else {
                if manager.windowState == .dragging {
                    manager.windowState = .detached
                }
                if manager.stateBeforeDrag == .detached {
                    manager.windowState = .detached
                }
            }

            manager.stateBeforeDrag = nil
            manager.isReadyToSnap = false
            if manager.windowState == .dragging {
                #if DEVELOPMENT
                DebugState.shared.userAction("结束拖动调试窗口")
                #endif
            }

        default:
            break
        }

        return event
    }

    /// 处理调试窗口的吸附
    private func handleDebugWindowSnap(debugWindow: NSWindow, mainWindow: NSWindow) {
        let frame = debugWindow.frame
        let mainFrame = mainWindow.frame
        var newFrame = frame

        // 判断吸附方向
        let snapDistance = manager.getEffectiveSnapDistance(for: frame, and: mainFrame)
        let distanceToLeftEdge = abs(frame.maxX - mainFrame.minX)
        let distanceToRightEdge = abs(frame.minX - mainFrame.maxX)

        if distanceToLeftEdge <= snapDistance {
            // 吸附到左边
            newFrame.origin.x = mainFrame.minX - frame.width - 1
            newFrame.origin.y = mainFrame.minY
            newFrame.size.height = mainFrame.height
            manager.debugWindowSide = .left
            #if DEVELOPMENT
            DebugState.shared.system("吸附到主窗口左侧")
            #endif
        } else if distanceToRightEdge <= snapDistance {
            // 吸附到右边
            newFrame.origin.x = mainFrame.maxX + 1
            newFrame.origin.y = mainFrame.minY
            newFrame.size.height = mainFrame.height
            manager.debugWindowSide = .right
            #if DEVELOPMENT
            DebugState.shared.system("吸附到主窗口右侧")
            #endif
        }

        // 执行吸附动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            debugWindow.animator().setFrame(newFrame, display: true)
        }, completionHandler: {
            mainWindow.addChildWindow(debugWindow, ordered: .above)
            #if DEVELOPMENT
            DebugState.shared.system("执行吸附动画并设置为子窗口")
            #endif
        })

        manager.windowState = .attached
    }

    /// 处理主窗口移动事件
    /// 主窗口移动时，如果 debug window 是子窗口，则更新 debug window 的位置
    /// 否则，不做任何操作
    @objc private func handleMainWindowMove(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              let debugWindow = manager.debugWindow,
              debugWindow.parent != nil else {
            return
        }

        // 更新调试窗口位置
        var newFrame = debugWindow.frame

        // 判断调试窗口在主窗口的哪一侧
        // if debugWindow.frame.minX < mainWindow.frame.minX {
        //     // 在左侧
        //     newFrame.origin.x = mainWindow.frame.minX - debugWindow.frame.width - 1
        // } else {
        //     // 在右侧
        //     newFrame.origin.x = mainWindow.frame.maxX + 1
        // }

        if manager.debugWindowSide == .left {
            newFrame.origin.x = mainWindow.frame.minX - debugWindow.frame.width - 1
        } else {
            newFrame.origin.x = mainWindow.frame.maxX + 1
        }

        newFrame.origin.y = mainWindow.frame.minY
        newFrame.size.height = mainWindow.frame.height
        debugWindow.setFrame(newFrame, display: true)
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
