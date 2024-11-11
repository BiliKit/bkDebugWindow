import AppKit

class WindowAnimator {
    private var window: NSWindow
    private let duration: TimeInterval = 0.3
    private let debugState = DebugState.shared

    init(window: NSWindow) {
        self.window = window
    }

    func animate(to targetFrame: NSRect, completion: (() -> Void)? = nil) {
        // 记录起始位置
        let startFrame = window.frame

        // 更新状态
        debugState.updateWindowState(
            position: startFrame.origin,
            isAnimating: true,
            targetPosition: targetFrame.origin,
            isProgrammaticMove: true
        )

        // 使用 NSAnimationContext 创建动画
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            self.window.setFrame(targetFrame, display: true)
            self.debugState.updateWindowState(
                position: targetFrame.origin,
                isAnimating: false,
                targetPosition: nil,
                isProgrammaticMove: false
            )
            completion?()
        })
    }
}