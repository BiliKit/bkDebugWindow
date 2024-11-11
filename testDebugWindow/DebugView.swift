import SwiftUI
import AppKit

/// 调试窗口的主视图
struct DebugView: View {
    // MARK: - 属性

    /// 调试状态对象
    @ObservedObject var debugState: DebugState = .shared
    /// 搜索文本
    @State private var searchText = ""

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
                messageListView
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

#Preview {
    DebugView()
        .environmentObject(DebugState.shared)
}
