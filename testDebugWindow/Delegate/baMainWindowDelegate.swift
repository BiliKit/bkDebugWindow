import AppKit
import SwiftUI


/// 主窗口的代理
class baMainWindowDelegate: NSObject, NSWindowDelegate {
    // MARK: - Properties
    static let shared = baMainWindowDelegate()
    private let manager = baWindowManager.shared
}