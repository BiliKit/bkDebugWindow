import AppKit
import SwiftUI

class WindowManager {
    // MARK: - Properties
    private weak var mainWindow: NSWindow?
    private var debugWindow: NSWindow?
    private var windowAnimator: WindowAnimator?
    private var isProgrammaticMove = false
    private let debugState = DebugState.shared

    // MARK: - Window Actions
    private var openWindow: ((String) -> Void)?
    private var dismissWindow: ((String) -> Void)?

    // MARK: - Initialization
    init(mainWindow: NSWindow?) {
        self.mainWindow = mainWindow
    }

    func setEnvironmentActions(
        open: @escaping (String) -> Void,
        dismiss: @escaping (String) -> Void
    ) {
        self.openWindow = open
        self.dismissWindow = dismiss
    }

    // MARK: - Window Management
    func setupDebugWindow() {
        guard let mainWindow = mainWindow,
              let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) else {
            debugState.error("Failed to setup debug window")
            return
        }

        self.debugWindow = debugWindow
        configureDebugWindow(debugWindow, mainWindow: mainWindow)
    }

    private func configureDebugWindow(_ debugWindow: NSWindow, mainWindow: NSWindow) {
        debugWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        debugWindow.isMovable = true
        debugWindow.level = mainWindow.level

        if debugState.isAttached {
            makeDebugWindowChild(of: mainWindow)
        }
    }

    // MARK: - Window Position Management
    func resetDebugWindow() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow else { return }

        isProgrammaticMove = true
        mainWindow.removeChildWindow(debugWindow)

        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
        animateWindow(debugWindow, to: targetFrame) { [weak self] in
            guard let self = self else { return }
            self.isProgrammaticMove = false
            self.debugState.isAttached = true
            self.makeDebugWindowChild(of: mainWindow)
        }
    }

    private func calculateDebugWindowFrame(mainWindow: NSWindow, debugWindow: NSWindow) -> NSRect {
        let mainFrame = mainWindow.frame
        let debugWidth = debugWindow.frame.width
        let screen = mainWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let newX = min(mainFrame.maxX, screen.visibleFrame.maxX - debugWidth)

        return NSRect(
            x: newX,
            y: mainFrame.minY,
            width: debugWidth,
            height: mainFrame.height
        )
    }

    private func animateWindow(_ window: NSWindow, to targetFrame: NSRect, completion: (() -> Void)? = nil) {
        windowAnimator = WindowAnimator(window: window)
        windowAnimator?.animate(to: targetFrame, completion: completion)
    }

    // MARK: - Child Window Management
    func makeDebugWindowChild(of mainWindow: NSWindow) {
        guard let debugWindow = debugWindow else { return }

        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
        debugWindow.setFrame(targetFrame, display: true)

        mainWindow.removeChildWindow(debugWindow)
        mainWindow.addChildWindow(debugWindow, ordered: .above)
        debugState.isAttached = true
    }

    // MARK: - Window State Management
    func handleWindowMove(_ window: NSWindow) {
        if isDebugWindow(window) {
            if !isProgrammaticMove {
                debugState.isAttached = false
            }
        } else {
            handleMainWindowMove(window)
        }
    }

    private func handleDebugWindowMove(_ window: NSWindow) {
        guard !isProgrammaticMove else { return }
        debugState.isAttached = false
    }

    private func handleMainWindowMove(_ window: NSWindow) {
        if debugState.isAttached {
            updateDebugWindowPosition()
        }
    }

    private func updateDebugWindowPosition() {
        guard let mainWindow = mainWindow,
              let debugWindow = debugWindow,
              debugWindow.parent == nil else { return }

        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
        animateWindow(debugWindow, to: targetFrame)
    }

    // MARK: - Utility Methods
    private func isDebugWindow(_ window: NSWindow) -> Bool {
        return window.identifier?.rawValue == "debug-window"
    }

    func toggleDebugWindow() {
        if debugState.isWindowOpen {
            closeDebugWindow()
        } else {
            openDebugWindow()
        }
    }

    private func openDebugWindow() {
        openWindow?("debug-window")
        debugState.isWindowOpen = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let mainWindow = self.mainWindow else { return }

            if self.debugState.isAttached {
                self.makeDebugWindowChild(of: mainWindow)
            }
        }
    }

    private func closeDebugWindow() {
        if let mainWindow = mainWindow,
           let debugWindow = debugWindow {
            mainWindow.removeChildWindow(debugWindow)
        }
        dismissWindow?("debug-window")
        debugState.isWindowOpen = false
    }
}