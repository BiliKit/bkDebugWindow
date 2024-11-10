import SwiftUI
import AppKit

class WindowAccessor {
    static func getWindow() -> NSWindow? {
        // 获取非调试窗口
        return NSApplication.shared.windows.first(where: {
            $0.identifier?.rawValue != "debug-window"
        })
    }
}
