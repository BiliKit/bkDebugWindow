import SwiftUI

// 定义消息类型枚举
enum DebugMessageType: String, CaseIterable {
    case info = "信息"
    case warning = "警告"
    case error = "错误"
    case userAction = "用户操作"
    case network = "网络"
    case system = "系统"
    case performance = "性能"

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .userAction: return .green
        case .network: return .cyan
        case .system: return .purple
        case .performance: return .yellow
        }
    }
}

// 定义调试消息结构
struct DebugMessage: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let type: DebugMessageType
    let content: String
    let details: String?

    var formattedMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(dateFormatter.string(from: timestamp))] [\(type.rawValue)] \(content)"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DebugMessage, rhs: DebugMessage) -> Bool {
        lhs.id == rhs.id
    }
}

class DebugState: ObservableObject {
    static let shared = DebugState()

    @Published var isAttached: Bool = false {
        didSet {
            if oldValue != isAttached {
                if isAttached {
                    lastNonAttachedFrame = windowFrame
                    if let screen = NSScreen.main {
                        let screenFrame = screen.visibleFrame
                        windowFrame = CGRect(
                            x: screenFrame.maxX - windowFrame.width,
                            y: screenFrame.minY,
                            width: windowFrame.width,
                            height: screenFrame.height
                        )
                    }
                } else if let lastFrame = lastNonAttachedFrame {
                    windowFrame = lastFrame
                }

                NotificationCenter.default.post(
                    name: NSNotification.Name("DebugWindowAttachStateChanged"),
                    object: nil
                )
            }
        }
    }

    @Published var isWindowOpen: Bool = false
    @Published var showDetails: Bool = false
    @Published var selectedMessageType: DebugMessageType? = nil
    @Published var debugMessages: [DebugMessage] = []

    @Published var windowFrame: CGRect = CGRect(x: 0, y: 0, width: 400, height: 600)
    private var lastNonAttachedFrame: CGRect?

    private let maxMessages = 1000

    private init() {
        showDetails = UserDefaults.standard.bool(forKey: "debug_window_show_details")
    }

    func addMessage(_ content: String, type: DebugMessageType, details: String? = nil) {
        let message = DebugMessage(timestamp: Date(), type: type, content: content, details: details)
        DispatchQueue.main.async {
            self.debugMessages.append(message)
            if self.debugMessages.count > self.maxMessages {
                self.debugMessages.removeFirst(self.debugMessages.count - self.maxMessages)
            }
        }
    }

    func clearMessages() {
        debugMessages.removeAll()
    }

    func filteredMessages() -> [DebugMessage] {
        if let selectedType = selectedMessageType {
            return debugMessages.filter { $0.type == selectedType }
        }
        return debugMessages
    }

    func updateWindowPosition(_ newFrame: CGRect) {
        if !isAttached {
            windowFrame = newFrame
        }
    }
}

// 便利方法扩展
extension DebugState {
    func info(_ message: String, details: String? = nil) {
        addMessage(message, type: .info, details: details)
    }

    func warning(_ message: String, details: String? = nil) {
        addMessage(message, type: .warning, details: details)
    }

    func error(_ message: String, details: String? = nil) {
        addMessage(message, type: .error, details: details)
    }

    func userAction(_ message: String, details: String? = nil) {
        addMessage(message, type: .userAction, details: details)
    }

    func network(_ message: String, details: String? = nil) {
        addMessage(message, type: .network, details: details)
    }

    func system(_ message: String, details: String? = nil) {
        addMessage(message, type: .system, details: details)
    }

    func performance(_ message: String, details: String? = nil) {
        addMessage(message, type: .performance, details: details)
    }
}