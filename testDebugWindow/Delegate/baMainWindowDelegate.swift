import AppKit
import SwiftUI
class baMainWindowDelegate: NSObject, NSWindowDelegate {
    // MARK: - Properties
    static let shared = baMainWindowDelegate()
    private let manager = baWindowManager.shared

}