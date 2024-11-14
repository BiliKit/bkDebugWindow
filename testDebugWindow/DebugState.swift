import SwiftUI

/// 调试消息类型枚举
enum DebugMessageType: String, CaseIterable {
    /// 普通信息
    case info = "信息"
    /// 警告信息
    case warning = "警告"
    /// 错误信息
    case error = "错误"
    /// 用户操作记录
    case userAction = "用户操作"
    /// 网络相关信息
    case network = "网络"
    /// 系统相关信息
    case system = "系统"
    /// 性能相关信息
    case performance = "性能"

    /// 每种消息类型对应的显示颜色
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

    /// 每种消息类型对应的SF Symbol图标
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .userAction: return "person.circle"
        case .network: return "network"
        case .system: return "gear"
        case .performance: return "gauge"
        }
    }
}

/// 调试消息结构体
struct DebugMessage: Identifiable, Hashable {
    /// 唯一标识符
    let id = UUID()
    /// 消息时间戳
    let timestamp: Date
    /// 消息类型
    let type: DebugMessageType
    /// 消息内容
    let content: String
    /// 详细信息（可选）
    let details: String?
    /// 线程名称
    let threadName: String

    /// 初始化方法
    init(timestamp: Date = Date(),
         type: DebugMessageType,
         content: String,
         details: String? = nil,
         threadName: String = Thread.current.name ?? "main") {
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.details = details
        self.threadName = threadName
    }

    /// 格式化的消息字符串
    var formattedMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"

        return "[\(dateFormatter.string(from: timestamp))][\(threadName)][\(type.rawValue)] \(content)"
    }

    /// Hashable协议实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Equatable协议实现
    static func == (lhs: DebugMessage, rhs: DebugMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// 调试状态管理类
class DebugState: ObservableObject {
    /// 单例实例
    static let shared = DebugState()

    // MARK: - 发布的属性

    /// 窗口吸附状态
    @Published var isAttached: Bool = false {
        didSet {
            if oldValue != isAttached {
                print("Debug: Attach state changed to \(isAttached)")
                notifyAttachStateChange()
                saveAttachState()
            }
        }
    }

    /// 窗口是否打开
    @Published var isWindowOpen: Bool = false
    /// 是否显示详细信息
    @Published var showDetails: Bool = false
    /// 当前选中的消息类型过滤器
    @Published var selectedMessageType: DebugMessageType? = nil
    /// 搜索文本
    @Published var searchText: String = ""
    /// 是否自动滚动
    @Published var autoScroll: Bool = true
    /// 调试消息数组
    @Published private(set) var debugMessages: [DebugMessage] = []
    /// 消息统计信息
    @Published private(set) var messageStats: [DebugMessageType: Int] = [:]
    /// 监视变量数组
    @Published private(set) var watchVariables: [WatchVariable] = []

    // 添加窗口状态结构体
    struct WindowState {
        var position: NSPoint = .zero
        var size: NSSize = .zero
        var isAnimating: Bool = false
        var targetPosition: NSPoint?
        var isProgrammaticMove: Bool = false
    }

    // 添加窗口状态属性
    @Published private(set) var windowState = WindowState() {
        didSet {
            updateWatchVariable(name: "windowState", value: windowState, type: "String")
            debugMessages.append(DebugMessage(
                type: .system,
                content: "windowState updated",
                details: "windowState: \(windowState)"
            ))
        }
    }

    // MARK: - 私有属性

    /// 消息处理队列
    private let messageQueue = DispatchQueue(label: "com.debug.messageQueue")
    /// 初始化状态标志
    private var isInitialized = false
    /// 最大消息数量
    private let maxMessages: Int

    // MARK: - 初始化方法

    private init(maxMessages: Int = 1000) {
        self.maxMessages = maxMessages

        // 添加初始化信息
        self.debugMessages.append(DebugMessage(
            type: .system,
            content: "正在初始化debugState...",
            details: "maxMessages: \(maxMessages)"
        ))

        self.loadSavedStates()
        self.updateMessageStats()
        DispatchQueue.main.async {
            self.isInitialized = true
            self.debugMessages.append(DebugMessage(
                type: .system,
                content: "初始化debugState完成",
                details: "isInitialized: \(self.isInitialized)"
            ))
        }
    }

    // MARK: - 私有方法

    /// 通知吸附状态变化
    private func notifyAttachStateChange() {
        NotificationCenter.default.post(
            name: NSNotification.Name("DebugWindowAttachStateChanged"),
            object: self,
            userInfo: [
                "isAttached": isAttached,
                "timestamp": Date()
            ]
        )
    }

    /// 保存吸附状态
    private func saveAttachState() {
        UserDefaults.standard.set(isAttached, forKey: "debug_window_is_attached")
    }

    /// 加载保存的状态
    private func loadSavedStates() {
        self.showDetails = UserDefaults.standard.bool(forKey: "debug_window_show_details")
        self.autoScroll = UserDefaults.standard.bool(forKey: "debug_window_auto_scroll")
        self.isAttached = UserDefaults.standard.bool(forKey: "debug_window_is_attached")
    }

    // MARK: - 公共方法

    /// 添加新的调试消息
    func addMessage(_ content: String, type: DebugMessageType, details: String? = nil) {
        print("DebugState: Adding message of type \(type)")
        messageQueue.async { [weak self] in
            guard let self = self else {
                print("DebugState: Failed to add message - self is nil")
                return
            }
            let message = DebugMessage(type: type, content: content, details: details)

            DispatchQueue.main.async {
                self.debugMessages.append(message)
                if self.debugMessages.count > self.maxMessages {
                    self.debugMessages.removeFirst(self.debugMessages.count - self.maxMessages)
                }
                self.updateMessageStats()
                print("DebugState: Message added successfully")
            }
        }
    }

    /// 清除所有消息
    func clearMessages() {
        debugMessages.removeAll()
        updateMessageStats()
    }

    /// 获取过滤后的消息列表
    func filteredMessages() -> [DebugMessage] {
        var messages = debugMessages

        if let selectedType = selectedMessageType {
            messages = messages.filter { $0.type == selectedType }
        }

        if !searchText.isEmpty {
            messages = messages.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                ($0.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return messages
    }

    /// 更新消息统计
    private func updateMessageStats() {
        var stats: [DebugMessageType: Int] = [:]
        for type in DebugMessageType.allCases {
            stats[type] = debugMessages.filter { $0.type == type }.count
        }
        messageStats = stats
    }

    /// 切换自动滚动状态
    func toggleAutoScroll() {
        autoScroll.toggle()
        UserDefaults.standard.set(autoScroll, forKey: "debug_window_auto_scroll")
    }

    /// 切换详情显示状态
    func toggleDetails() {
        showDetails.toggle()
        UserDefaults.standard.set(showDetails, forKey: "debug_window_show_details")
    }

    // MARK: - 重置方法

    // 添加重置方法
    func reset() {
        self.debugMessages.append(DebugMessage(
            type: .system,
            content: "DebugState reset initiated",
            details: "Previous message count: \(debugMessages.count)"
        ))

        DispatchQueue.main.async {
            self.debugMessages.removeAll()
            self.updateMessageStats()
            self.loadSavedStates()
            self.isInitialized = true

            // 添加重置完成信息
            self.debugMessages.append(DebugMessage(
                type: .system,
                content: "DebugState reset completed",
                details: """
                showDetails: \(self.showDetails)
                autoScroll: \(self.autoScroll)
                isAttached: \(self.isAttached)
                isInitialized: \(self.isInitialized)
                """
            ))
        }
    }

    deinit {
        self.debugMessages.append(DebugMessage(
            type: .system,
            content: "DebugState deinitializing",
            details: "Final message count: \(debugMessages.count)"
        ))
        NotificationCenter.default.removeObserver(self)
    }

    // 添加更新监视变量的方法
    func updateWatchVariable(name: String, value: Any, type: String) {
        guard !name.isEmpty else {
            self.error("Failed to update watch variable: Empty name")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let stringValue = String(describing: value)
            if let index = self.watchVariables.firstIndex(where: { $0.name == name }) {
                // 更新现有变量
                let oldValue = self.watchVariables[index].value
                self.watchVariables[index] = WatchVariable(
                    name: name,
                    value: stringValue,
                    type: type
                )
            } else {
                // 添加新变量
                self.watchVariables.append(WatchVariable(
                    name: name,
                    value: stringValue,
                    type: type
                ))
            }
        }
    }

    // 清除监视变量
    func clearWatchVariables() {
        watchVariables.removeAll()
    }

    // 移除特定监视变量
    func removeWatchVariable(name: String) {
        watchVariables.removeAll { $0.name == name }
    }

    // 添加一个方法来注册可观察变量
    func registerWatchable(_ variable: WatchableVariable) {
        updateWatchVariable(
            name: variable.name,
            value: variable.valueString,
            type: variable.type
        )

        // 添加观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchableChange(_:)),
            name: .watchableVariableDidChange,
            object: variable
        )
    }

    @objc private func handleWatchableChange(_ notification: Notification) {
        guard let variable = notification.object as? WatchableVariable else { return }
        updateWatchVariable(
            name: variable.name,
            value: variable.valueString,
            type: variable.type
        )
    }

    // 添加更窗口状态的方法
    func updateWindowState(
        position: NSPoint? = nil,
        size: NSSize? = nil,
        isAnimating: Bool? = nil,
        targetPosition: NSPoint? = nil,
        isProgrammaticMove: Bool? = nil
    ) {
        DispatchQueue.main.async {
            if let position = position {
                self.windowState.position = position
            }
            if let size = size {
                self.windowState.size = size
            }
            if let isAnimating = isAnimating {
                self.windowState.isAnimating = isAnimating
            }
            if let targetPosition = targetPosition {
                self.windowState.targetPosition = targetPosition
            }
            if let isProgrammaticMove = isProgrammaticMove {
                self.windowState.isProgrammaticMove = isProgrammaticMove
            }

            // 添加到监视变量
            self.updateWatchVariable(
                name: "windowPosition",
                value: "(\(Int(self.windowState.position.x)), \(Int(self.windowState.position.y)))",
                type: "Window"
            )
            if let target = self.windowState.targetPosition {
                self.updateWatchVariable(
                    name: "targetPosition",
                    value: "(\(Int(target.x)), \(Int(target.y)))",
                    type: "Window"
                )
            }
            self.updateWatchVariable(
                name: "isAnimating",
                value: self.windowState.isAnimating,
                type: "Window"
            )
            self.updateWatchVariable(
                name: "isProgrammaticMove",
                value: self.windowState.isProgrammaticMove,
                type: "Window"
            )
        }
    }
}

// MARK: - 便利方法扩展
extension DebugState {
    /// 添加信息类型的消息
    func info(_ message: String, details: String? = nil) {
        addMessage(message, type: .info, details: details)
    }

    /// 添加警告类型的消息
    func warning(_ message: String, details: String? = nil) {
        addMessage(message, type: .warning, details: details)
    }

    /// 添加错误类型的消息
    func error(_ message: String, details: String? = nil) {
        addMessage(message, type: .error, details: details)
    }

    /// 添加用户操作类型的消息
    func userAction(_ message: String, details: String? = nil) {
        addMessage(message, type: .userAction, details: details)
    }

    /// 添加网络类型的消息
    func network(_ message: String, details: String? = nil) {
        addMessage(message, type: .network, details: details)
    }

    /// 添加系统类型的消息
    func system(_ message: String, details: String? = nil) {
        addMessage(message, type: .system, details: details)
    }

    /// 添加性能类型的消息
    func performance(_ message: String, details: String? = nil) {
        addMessage(message, type: .performance, details: details)
    }
}

// 添加一个用于存储监视变量的结构体
struct WatchVariable: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var value: String
    let type: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WatchVariable, rhs: WatchVariable) -> Bool {
        lhs.id == rhs.id
    }
}

// 添加一个用于存储监视变量的协议
protocol WatchableVariable {
    var name: String { get }
    var type: String { get }
    var valueString: String { get }
}

// 添加一个泛型包装器来观察变量
@propertyWrapper
class Watchable<T>: WatchableVariable {
    private var value: T
    let name: String
    let type: String

    var wrappedValue: T {
        get { value }
        set {
            value = newValue
            // 当值改变时通知 DebugState
            NotificationCenter.default.post(
                name: .watchableVariableDidChange,
                object: self
            )
        }
    }

    var projectedValue: Watchable<T> { self }

    init(wrappedValue: T, name: String, type: String) {
        self.value = wrappedValue
        self.name = name
        self.type = type
    }

    var valueString: String {
        String(describing: value)
    }
}

extension Notification.Name {
    static let watchableVariableDidChange = Notification.Name("watchableVariableDidChange")
}
