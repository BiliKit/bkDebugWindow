// import AppKit

// class WindowAnimator {
//     private var window: NSWindow
//     private let duration: TimeInterval = 0.3
//     private let debugState = DebugState.shared

//     init(window: NSWindow) {
//         self.window = window
//     }

//     func animate(to targetFrame: NSRect, completion: (() -> Void)? = nil) {
//         // 记录起始位置
//         let startFrame = window.frame

//         // 更新状态
//         debugState.updateWindowState(
//             position: startFrame.origin,
//             isAnimating: true,
//             targetPosition: targetFrame.origin,
//             isProgrammaticMove: true
//         )

//         // 使用 NSAnimationContext 创建动画
//         NSAnimationContext.runAnimationGroup({ context in
//             context.duration = duration
//             context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
//             context.allowsImplicitAnimation = true
//             window.animator().setFrame(targetFrame, display: true)
//         }, completionHandler: {
//             self.window.setFrame(targetFrame, display: true)
//             self.debugState.updateWindowState(
//                 position: targetFrame.origin,
//                 isAnimating: false,
//                 targetPosition: nil,
//                 isProgrammaticMove: false
//             )
//             completion?()
//         })
//     }
// }



import Foundation
import SwiftUI
import Cocoa

private class FrameObserverView: NSView {    // 更明确地表示这是一个观察frame的视图
    var lastFrame: NSRect = .zero            // 'previous' 改为 'last' 更简洁
    var onFrameChange: ((NSRect) -> Void)?   // 更符合 Swift 命名规范的回调命名

    override var frame: NSRect {
        get { super.frame }
        set {
            super.frame = newValue
            defer { lastFrame = newValue }
            if newValue != lastFrame { onFrameChange?(newValue) }
        }
    }
}

struct ViewFrameReader: NSViewRepresentable {
    let onFrameChange: (NSRect) -> Void      // 保持命名一致性

    func makeNSView(context _: Context) -> NSView {
        let view = FrameObserverView()
        view.onFrameChange = { onFrameChange($0) }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}


private class WindowFrameObserverView: NSView {
    var lastFrame: NSRect = .zero
    var onFrameChange: ((NSRect) -> Void)?

    override var frame: NSRect {
        get { super.frame }
        set {
            super.frame = newValue
            defer { lastFrame = newValue }
            if newValue != lastFrame { onFrameChange?(newValue) }
        }
    }

    // 添加窗口位置监听
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onFrameChange?(window.frame)
    }
}

struct WindowFrameReader: NSViewRepresentable {
    let onFrameChange: (NSRect) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = WindowFrameObserverView()
        view.onFrameChange = { onFrameChange($0) }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}
