class DebugViewModel: ObservableObject {
    // 使用分页加载消息
    private let pageSize = 50
    @Published private(set) var messages: [DebugMessage] = []

    func loadMoreMessages() {
        // 分页加载实现
    }

    // 使用节流控制更新频率
    private var updateTimer: Timer?
    func throttledUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1) { [weak self] _ in
            self?.update()
        }
    }
}