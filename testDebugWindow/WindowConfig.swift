import SwiftUI
import AppKit

class WindowConfig {
    static func configureDebugWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "调试窗口" }) {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .visible
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
                window.isMovableByWindowBackground = true

                // 设置标题文字颜色
                if let titleView = window.standardWindowButton(.closeButton)?.superview?.superview {
                    titleView.wantsLayer = true
                    titleView.layer?.backgroundColor = NSColor.clear.cgColor
                }
            }
        }
    }
}