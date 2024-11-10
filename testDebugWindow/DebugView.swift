import SwiftUI
import AppKit

/// 调试窗口的主视图
struct DebugView: View {
    // MARK: - 属性

    /// 调试状态对象
    @StateObject private var debugState = DebugState.shared
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
        .frame(minWidth: 330, minHeight: 300)
        .background(WindowDragHandler())
        .task {
            WindowConfig.configureDebugWindow()
        }
    }

    // MARK: - 子视图

    /// 工具栏视图
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 修复 Picker 的语法
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

            // 搜索框
            TextField("搜索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .font(.system(size: 12))

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
    @StateObject private var debugState = DebugState.shared
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
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.backgroundColor = .windowBackgroundColor
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#Preview {
    DebugView()
        .environmentObject(DebugState.shared)
}
