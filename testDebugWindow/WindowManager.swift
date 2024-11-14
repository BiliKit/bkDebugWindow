import AppKit
import SwiftUI
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()

    let debugWindowName = "debugWindow"

    @Published var observers: [NSObjectProtocol] = []

    // debug window 在哪一侧
    var debugWindowSide: Side = .right {
        didSet {
            DebugState.shared.updateWatchVariable(name: "debugWindowSide", value: debugWindowSide.rawValue, type: "String")
        }
    }

    enum Side: String {
        case left = "左侧"
        case right = "右侧"
    }

    // 窗口尺寸配置
    let defaultMainWindowWidth: CGFloat = 400
    let defaultMainWindowHeight: CGFloat = 600
    let defaultDebugWindowWidth: CGFloat = 350

    // 吸附配置
    let snapDistanceOutside: CGFloat = 70    // 外部吸附距离
    let snapDistanceInside: CGFloat = 290    // 内部吸附距离
    let dragStartThreshold: CGFloat = 0      // 拖动开始阈值

    var activeWindow: NSWindow?

    /// 目标窗口位置
    @Published var targetFrame: NSRect = .zero {
        didSet {
            DebugState.shared.updateWatchVariable(name: "targetFrameX", value: targetFrame.origin.x, type: "Int")
            DebugState.shared.updateWatchVariable(name: "targetFrameY", value: targetFrame.origin.y, type: "Int")
        }
    }

    /// 目标窗口高度
    @Published var targetPosition: CGPoint = .zero

    /// 是否需要更新窗口位置
    @Published var needUpdate = false {
        didSet {
            DebugState.shared.updateWatchVariable(name: "needUpdate", value: needUpdate, type: "Bool")
        }
    }

    /// 最后一次更新时间
    @Published var lastUpdate: Date = .init()

    // 状态追踪
    @Published var windowMode: WindowMode = .direct {
        didSet {
            DebugState.shared.updateWatchVariable(name: "windowMode", value: windowMode.rawValue, type: "String")
        }
    }
    @Published var isReadyToSnap = false {
        didSet {
            DebugState.shared.updateWatchVariable(name: "isReadyToSnap", value: isReadyToSnap, type: "Bool")
        }
    }
    @Published var windowState: WindowState = .attached {
        didSet {
            DebugState.shared.updateWatchVariable(name: "windowState", value: windowState.rawValue, type: "String")
        }
    }

    // 窗口引用
    var debugWindow: NSWindow?
    var mainWindow: NSWindow?

    // 拖动状态追踪
    var dragStartLocation: NSPoint?          // 替代 initialClickLocation
    var stateBeforeDrag: WindowState?        // 替代 initialState

    private init() {} // 确保单例

    // 辅助方法
    func isWindowsOverlapping(_ frame1: NSRect, _ frame2: NSRect) -> Bool {
        return frame1.intersects(frame2)
    }

    func getEffectiveSnapDistance(for frame1: NSRect, and frame2: NSRect) -> CGFloat {
        return isWindowsOverlapping(frame1, frame2) ? snapDistanceInside : snapDistanceOutside
    }

    func isValueBetween(_ value: CGFloat, min: CGFloat, max: CGFloat) -> Bool {
        return value >= min && value <= max
    }

    // 窗口状态枚举
    enum WindowState: String {
        case attached = "已吸附"
        case detached = "已分离"
        case dragging = "拖拽中"
    }

    enum WindowMode: String {
        case animation = "动画"
        case direct = "直接"
    }

    // 窗口吸附动画方法
    func snapDebugWindowToMain() {  // 替代 animateWindowSnap
        let windows = NSApplication.shared.windows
        guard let currentWindow = windows.first(where: { $0.title == "debugWindow" }),
              let mainWindow = windows.first(where: { $0.title != "debugWindow" }) else { return }

        print("currentWindow: \(currentWindow.title)")
        print("mainWindow: \(mainWindow.title)")

        let currentFrame = currentWindow.frame
        var newFrame = currentFrame

        // 计算贴合位置
        if currentWindow.frame.midX < mainWindow.frame.midX {
            // 当前窗口在左边，贴合到目标窗口的左边
            newFrame.origin.x = mainWindow.frame.minX - currentFrame.width - 1
            newFrame.origin.y = mainWindow.frame.minY
            newFrame.size.height = mainWindow.frame.size.height
        } else {
            // 当前窗口在右边，贴合到目标窗口的右边
            newFrame.origin.x = mainWindow.frame.maxX + 1
            newFrame.origin.y = mainWindow.frame.minY
            newFrame.size.height = mainWindow.frame.size.height
        }

        // 动画1
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true

            currentWindow.animator().setFrame(newFrame, display: true, animate: true)
        }, completionHandler: {
            // 动画完成后设置为子窗口
            mainWindow.addChildWindow(currentWindow, ordered: .above)
            #if DEVELOPMENT
            DebugState.shared.addMessage("吸附完成", type: .info)
            #endif
        })

        // 动画2：使用 Core Animation 显式动画
        // let animation = CABasicAnimation(keyPath: "frame")
        // animation.fromValue = NSValue(rect: currentFrame)
        // animation.toValue = NSValue(rect: newFrame)
        // animation.duration = 0.45
        // animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // currentWindow.animations = ["frame": animation]
        // currentWindow.animator().setFrame(newFrame, display: true)

        // DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration) {
        //     mainWindow.addChildWindow(currentWindow, ordered: .above)
        //     DebugState.shared.addMessage("吸附完成", type: .info)
        // }

        // 动画3：使用弹簧动画效果
        // NSAnimationContext.runAnimationGroup({ context in
        // context.duration = 0.8
        // context.timingFunction = CAMediaTimingFunction(
        //     controlPoints: 0.5, 1.8, 0.585, 0.885
        // )
        // context.allowsImplicitAnimation = true

        // currentWindow.animator().setFrame(newFrame, display: true, animate: true)
        // }, completionHandler: {
        //     mainWindow.addChildWindow(currentWindow, ordered: .above)
        //     DebugState.shared.addMessage("吸附完成", type: .info)
        // })

        // 动画4：分步动画
        // let positionFrame = NSRect(
        //     x: newFrame.origin.x,
        //     y: currentFrame.origin.y,
        //     width: currentFrame.width,
        //     height: currentFrame.height
        // )

        // NSAnimationContext.runAnimationGroup({ context in
        //     context.duration = 0.25
        //     context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        //     currentWindow.animator().setFrame(positionFrame, display: true)
        // }, completionHandler: {
        //     // 第二步：调整大小
        //     NSAnimationContext.runAnimationGroup({ context in
        //         context.duration = 0.2
        //         context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        //         currentWindow.animator().setFrame(newFrame, display: true)
        //     }, completionHandler: {
        //         mainWindow.addChildWindow(currentWindow, ordered: .above)
        //         DebugState.shared.addMessage("吸附完成", type: .info)
        //     })
        // })

        // 设置状态
        windowState = .attached
    }
}

//class WindowManager1 {
//    // MARK: - Properties
//    private weak var mainWindow: NSWindow?
//    private var debugWindow: NSWindow?
//    private var windowAnimator: WindowAnimator?
//    private var isProgrammaticMove = false
//    private let debugState = DebugState.shared
//
//    // MARK: - Window Actions
//    private var openWindow: ((String) -> Void)?
//    private var dismissWindow: ((String) -> Void)?
//
//    // MARK: - Initialization
//    init(mainWindow: NSWindow?) {
//        self.mainWindow = mainWindow
//    }
//
//    func setEnvironmentActions(
//        open: @escaping (String) -> Void,
//        dismiss: @escaping (String) -> Void
//    ) {
//        self.openWindow = open
//        self.dismissWindow = dismiss
//    }
//
//    // MARK: - Window Management
//    func setupDebugWindow() {
//        guard let mainWindow = mainWindow,
//              let debugWindow = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "debug-window" }) else {
//            debugState.error("Failed to setup debug window")
//            return
//        }
//
//        self.debugWindow = debugWindow
//        configureDebugWindow(debugWindow, mainWindow: mainWindow)
//    }
//
//    private func configureDebugWindow(_ debugWindow: NSWindow, mainWindow: NSWindow) {
//        debugWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
//        debugWindow.isMovable = true
//        debugWindow.level = mainWindow.level
//
//        if debugState.isAttached {
//            makeDebugWindowChild(of: mainWindow)
//        }
//    }
//
//    // MARK: - Window Position Management
//    func resetDebugWindow() {
//        guard let mainWindow = mainWindow,
//              let debugWindow = debugWindow else { return }
//
//        isProgrammaticMove = true
//        mainWindow.removeChildWindow(debugWindow)
//
//        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
//        animateWindow(debugWindow, to: targetFrame) { [weak self] in
//            guard let self = self else { return }
//            self.isProgrammaticMove = false
//            self.debugState.isAttached = true
//            self.makeDebugWindowChild(of: mainWindow)
//        }
//    }
//
//    private func calculateDebugWindowFrame(mainWindow: NSWindow, debugWindow: NSWindow) -> NSRect {
//        let mainFrame = mainWindow.frame
//        let debugWidth = debugWindow.frame.width
//        let screen = mainWindow.screen ?? NSScreen.main ?? NSScreen.screens.first!
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
//    private func animateWindow(_ window: NSWindow, to targetFrame: NSRect, completion: (() -> Void)? = nil) {
//        windowAnimator = WindowAnimator(window: window)
//        windowAnimator?.animate(to: targetFrame, completion: completion)
//    }
//
//    // MARK: - Child Window Management
//    func makeDebugWindowChild(of mainWindow: NSWindow) {
//        guard let debugWindow = debugWindow else { return }
//
//        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
//        debugWindow.setFrame(targetFrame, display: true)
//
//        mainWindow.removeChildWindow(debugWindow)
//        mainWindow.addChildWindow(debugWindow, ordered: .above)
//        debugState.isAttached = true
//    }
//
//    // MARK: - Window State Management
//    func handleWindowMove(_ window: NSWindow) {
//        if isDebugWindow(window) {
//            if !isProgrammaticMove {
//                debugState.isAttached = false
//            }
//        } else {
//            handleMainWindowMove(window)
//        }
//    }
//
//    private func handleDebugWindowMove(_ window: NSWindow) {
//        guard !isProgrammaticMove else { return }
//        debugState.isAttached = false
//    }
//
//    private func handleMainWindowMove(_ window: NSWindow) {
//        if debugState.isAttached {
//            updateDebugWindowPosition()
//        }
//    }
//
//    private func updateDebugWindowPosition() {
//        guard let mainWindow = mainWindow,
//              let debugWindow = debugWindow,
//              debugWindow.parent == nil else { return }
//
//        let targetFrame = calculateDebugWindowFrame(mainWindow: mainWindow, debugWindow: debugWindow)
//        animateWindow(debugWindow, to: targetFrame)
//    }
//
//    // MARK: - Utility Methods
//    private func isDebugWindow(_ window: NSWindow) -> Bool {
//        return window.identifier?.rawValue == "debug-window"
//    }
//
//    func toggleDebugWindow() {
//        if debugState.isWindowOpen {
//            closeDebugWindow()
//        } else {
//            openDebugWindow()
//        }
//    }
//
//    private func openDebugWindow() {
//        openWindow?("debug-window")
//        debugState.isWindowOpen = true
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
//            guard let self = self,
//                  let mainWindow = self.mainWindow else { return }
//
//            if self.debugState.isAttached {
//                self.makeDebugWindowChild(of: mainWindow)
//            }
//        }
//    }
//
//    private func closeDebugWindow() {
//        if let mainWindow = mainWindow,
//           let debugWindow = debugWindow {
//            mainWindow.removeChildWindow(debugWindow)
//        }
//        dismissWindow?("debug-window")
//        debugState.isWindowOpen = false
//    }
//}
