import SwiftUI
import AppKit

/// 调试窗口的主视图
struct DebugView: View {
    // MARK: - 属性

    /// 调试状态对象
    @ObservedObject var debugState: DebugState = .shared
    /// 搜索文本
    @State private var searchText = ""
    @State private var showWatchPanel: Bool = true // 添加控制监视面板显示的状态

    /// 过滤后的消息列表
    private var filteredMessages: [DebugMessage] {
        let messages = debugState.filteredMessages()
        if searchText.isEmpty {
            return messages
        }
        return messages.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - 视图构建

    var body: some View {
        ZStack {
            // 背景色
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                toolbarView
                Divider()

                // 使用 GeometryReader 来管理布局
                GeometryReader { geometry in
                    VSplitView {
                        // 消息列表
                        messageListView
                            .frame(maxHeight: .infinity)

                        // 变量监视面板
                        if showWatchPanel {
                            watchPanelView
                                .frame(minHeight: 60, maxHeight: 120)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
        .background(WindowDragHandler())
        .task {
            WindowConfig.configureDebugWindow()
        }
        .onAppear {
            debugState.addMessage("DebugView: Appeared", type: .info)
            setupWindowChangeObserver()
        }
        .onDisappear {
            print("DebugView: Disappeared")
            // 发送重置通知
            NotificationCenter.default.post(
                name: NSNotification.Name("ResetDebugState"),
                object: nil
            )
        }
    }

    // MARK: - 子视图

    /// 工具栏视图
    private var toolbarView: some View {
        VStack(spacing: 8) {
            // 第一行
            HStack(spacing: 12) {
                // 类型选择器
                Picker("类型", selection: $debugState.selectedMessageType) {
                    Text("全部").tag(Optional<DebugMessageType>.none)
                    ForEach(DebugMessageType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                        }
                        .tag(Optional<DebugMessageType>.some(type))
                    }
                }
                .frame(width: 100)

                // 详情显示开关
                Toggle("详情", isOn: Binding(
                    get: { debugState.showDetails },
                    set: { newValue in
                        withAnimation {
                            debugState.showDetails = newValue
                        }
                        UserDefaults.standard.set(newValue, forKey: "debug_window_show_details")
                    }
                ))
                .toggleStyle(.switch)

                // 吸附开关
                Toggle("吸附", isOn: $debugState.isAttached)
                    .toggleStyle(.switch)

                // 清除按钮
                Button(action: {
                    debugState.clearMessages()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("清除所有消息")

                // 添加监视面板开关
                Toggle("监视", isOn: $showWatchPanel)
                    .toggleStyle(.switch)

                Spacer()
            }

            // 第二行
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                // 搜索框
                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    /// 消息列表视图
    private var messageListView: some View {
        Group {
            if filteredMessages.isEmpty {
                emptyStateView
            } else {
                messageScrollView
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("暂无调试信息")
                .foregroundColor(.gray)
                .font(.system(size: 13))
            Spacer()
        }
    }

    /// 消息滚动视图
    private var messageScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredMessages) { message in
                        MessageRow(message: message)
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: debugState.debugMessages.count) { oldValue, newValue in
                if let lastMessage = filteredMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // 添加变量监视面板视图
    private var watchPanelView: some View {
        VStack(spacing: 0) {
            // 监视面板头部
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "gauge")
                        .font(.system(size: 11))
                    Text("变量监视")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    debugState.clearWatchVariables()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("清除所有监视变量")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)

            Divider()

            // 修改变量列表布局
            if debugState.watchVariables.isEmpty {
                VStack {
                    Text("暂无监视变量")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(height: 30)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    FlowLayout(spacing: 4) {
                        ForEach(debugState.watchVariables) { variable in
                            WatchVariableRow(variable: variable)
                                .fixedSize()
                        }
                    }
                    .padding(4)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minHeight: 60, maxHeight: 120)
    }
}

/// 单条消息行视图
private struct MessageRow: View {
    @ObservedObject var debugState: DebugState = .shared
    let message: DebugMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 消息主体
            HStack {
                Image(systemName: message.type.icon)
                    .foregroundColor(message.type.color)
                Text(message.formattedMessage)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(message.type.color)
            .textSelection(.enabled)

            // 详细信息（如果有）
            if let details = message.details {
                if debugState.showDetails {
                    Text(details)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                        .textSelection(.enabled)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.03))
                .padding(.horizontal, 4)
        )
        .animation(.easeInOut(duration: 0.2), value: debugState.showDetails)
    }
}

/// 添加监视变量行视图
struct WatchVariableRow: View {
    let variable: WatchVariable
    @ObservedObject var debugState: DebugState = .shared

    // 根据变量类型和值获取显示颜色
    private var valueColor: Color {
        // 处理布尔值
        if variable.value == "true" {
            return .green
        } else if variable.value == "false" {
            return .red
        }

        // 根据变量类型设置颜色
        switch variable.type {
        case "Int", "Double", "Float":  // 数字类型
            return .blue
        case "String":                  // 字符串类型
            return .orange
        case "Window":                  // 窗口相关状态
            return .purple
        case "Bool":                    // 布尔值（非 true/false 的情况）
            return .gray
        default:                        // 其他类型
            return .primary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // 变量名和值
            HStack(spacing: 4) {
                Text(variable.name)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("=")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(variable.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(valueColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 删除按钮
            Button(action: {
                debugState.removeWatchVariable(name: variable.name)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .opacity(0.6)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
        .frame(height: 16)
    }
}

/// 窗口拖动处理器
struct WindowDragHandler: NSViewRepresentable {
    @ObservedObject var debugState: DebugState = .shared
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.backgroundColor = .windowBackgroundColor
            // debugState.addMessage("窗口背景色已设置为 \(String(describing: window.backgroundColor))", type: .info)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension DebugView {
    func setupWindowChangeObserver() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: nil) { notification in
            guard let window = notification.object as? NSWindow else { return }
            debugState.addMessage("调试信息窗口状态已改变: \(window.occlusionState.rawValue)", type: .info, details: "窗口状态: \(window.occlusionState.rawValue)")
        }

        notificationCenter.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: nil) { notification in
            debugState.addMessage("调试信息窗口大小改变", type: .info, details: "窗口大小: \(String(describing: notification.object))")
        }

        notificationCenter.addObserver(forName: NSWindow.willMoveNotification, object: nil, queue: nil) { notification in
            debugState.addMessage("调试信息窗口即将移动", type: .info, details: "窗口移动: \(String(describing: notification.object))")
        }

        notificationCenter.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: nil) { notification in
            debugState.addMessage("调试信息窗口已移动", type: .info, details: "窗口移动: \(String(describing: notification.object))")
        }

        notificationCenter.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: nil) { notification in
            guard let window = notification.object as? NSWindow else { return }
            debugState.addMessage("调试信息窗口已激活", type: .info, details: "窗口激活: \(window.title)")
        }
    }
}

// 添加 FlowLayout 视图来实现流式布局
struct FlowLayout: Layout {
    /// 元素之间的间距
    var spacing: CGFloat = 4

    /// 计算布局大小
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    /// 放置子视图
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)

        // 遍历每一行放置子视图
        for row in result.rows {
            for item in row {
                let x = bounds.minX + item.x
                let y = bounds.minY + item.y
                item.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    /// 流式布局结果结构
    struct FlowResult {
        /// 所有行
        var rows: [[Item]] = []
        /// 总高度
        var height: CGFloat = 0

        /// 布局项结构
        struct Item {
            let subview: LayoutSubview
            var size: CGSize
            var x: CGFloat
            var y: CGFloat
        }

        /// 初始化并计算布局
        init(in width: CGFloat, spacing: CGFloat, subviews: LayoutSubviews) {
            var currentRow: [Item] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0

            // 遍历所有子视图计算位置
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                // 如果当前行放不下，开始新行
                if x + size.width > width && !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }

                currentRow.append(Item(subview: subview, size: size, x: x, y: y))
                x += size.width + spacing
                maxHeight = max(maxHeight, size.height)
            }

            // 处理最后一行
            if !currentRow.isEmpty {
                rows.append(currentRow)
                y += maxHeight
            }

            self.height = y
        }
    }
}

#Preview {
    DebugView()
        .environmentObject(DebugState.shared)
}
