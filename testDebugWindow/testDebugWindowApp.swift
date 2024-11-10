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
    var isAnimating = false
    var isUserDraggingDebugWindow = false

    private func isDebugWindow(_ window: NSWindow) -> Bool {
        return window.identifier?.rawValue == "debug-window"
    }

    // 窗口大小改变
    func windowDidResize(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              !isDebugWindow(mainWindow) else { return }
        self.mainWindow = mainWindow
        if DebugState.shared.isAttached {
            updateDebugWindowFrame(mainWindow: mainWindow, animated: false)
        }
    }

    // 修改窗口开始移动的处理
    func windowWillStartLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              isDebugWindow(window) else { return }
        isUserDraggingDebugWindow = true
    }

    // 修改窗口移动的处理
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            // 确保是用户拖动导致的移动
            if isUserDraggingDebugWindow {
                // 立即取消吸附
                if DebugState.shared.isAttached {
                    DebugState.shared.isAttached = false
                }
            }
        } else {
            self.mainWindow = window
            if DebugState.shared.isAttached {
                updateDebugWindowFrame(mainWindow: window, animated: false)
            }
        }
    }

    // 修改窗口结束移动的处理
  func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if isDebugWindow(window) {
            isUserDraggingDebugWindow = false
        }
    }

    // 窗口最小化
    func windowDidMiniaturize(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              !isDebugWindow(mainWindow) else { return }
        debugWindow?.miniaturize(nil)
    }

    // 窗口恢复
    func windowDidDeminiaturize(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              !isDebugWindow(mainWindow) else { return }
        debugWindow?.deminiaturize(nil)
        if DebugState.shared.isAttached {
            updateDebugWindowFrame(mainWindow: mainWindow, animated: true)
        }
    }

    // 窗口关闭
    func windowWillClose(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              !isDebugWindow(mainWindow) else { return }
        debugWindow?.close()
        DebugState.shared.isWindowOpen = false
    }

    // 窗口获得焦点
    func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if isDebugWindow(window) {
            if let mainWindow = self.mainWindow {
                debugWindow?.level = mainWindow.level
                if DebugState.shared.isAttached {
                    updateDebugWindowFrame(mainWindow: mainWindow, animated: true)
                }
            }
        } else {
            self.mainWindow = window
            debugWindow?.level = window.level
            if DebugState.shared.isAttached {
                updateDebugWindowFrame(mainWindow: window, animated: true)
            }
            DebugState.shared.isWindowOpen = debugWindow?.isVisible ?? false
        }
    }

    // 窗口失去焦点
    func windowDidResignMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if !isDebugWindow(window) {
            let nextMainWindow = NSApplication.shared.mainWindow
            if nextMainWindow == nil || isDebugWindow(nextMainWindow!) {
                return
            }
            debugWindow?.level = .normal
            debugWindow?.orderBack(nil)
        }
    }

    func updateDebugWindowFrame(mainWindow: NSWindow, animated: Bool = true) {
        guard let debugWindow = self.debugWindow,
              let screen = mainWindow.screen else { return }

        let mainFrame = mainWindow.frame
        let maxX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWindow.frame.width)

        let debugFrame = NSRect(
            x: maxX,
            y: mainFrame.minY,
            width: debugWindow.frame.width,
            height: mainFrame.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                debugWindow.animator().setFrame(debugFrame, display: true)
            }
        } else {
            debugWindow.setFrame(debugFrame, display: true)
        }
    }

    func setupDebugWindow(with mainWindow: NSWindow) {
        guard let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) else { return }

        self.debugWindow = debugWindow
        self.mainWindow = mainWindow

        // 配置调试窗口
        debugWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        debugWindow.level = mainWindow.level
        debugWindow.isMovable = true

        // 为调试窗口设置代理
        debugWindow.delegate = self

        // 确保主窗口的代理设置正确
        mainWindow.delegate = self

        // 初始化位置
        if DebugState.shared.isAttached {
            updateDebugWindowFrame(mainWindow: mainWindow, animated: false)
        }

        // 更新状态
        DebugState.shared.isWindowOpen = true
    }

    override init() {
        super.init()
        // 添加对吸附状态变化的观察
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DebugWindowAttachStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self,
                  let mainWindow = self.mainWindow else { return }

            if DebugState.shared.isAttached {
                self.updateDebugWindowFrame(mainWindow: mainWindow, animated: true)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let windowDelegate = WindowDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let mainWindow = NSApplication.shared.windows.first(where: { !($0.identifier?.rawValue == "debug-window") }) {
                self.windowDelegate.setupDebugWindow(with: mainWindow)
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
                .onAppear {
                    // 设置窗口基本属性
                    if let window = WindowAccessor.getWindow() {
                        window.center()
                        window.setFrameAutosaveName("Main Window")
                    }
                }
        }

        #if DEBUG
        Window("调试窗口", id: "debug-window") {
            DebugView()
        }
        .defaultSize(width: 400, height: 300)
        .windowResizability(.contentSize)
        #endif
    }
}
