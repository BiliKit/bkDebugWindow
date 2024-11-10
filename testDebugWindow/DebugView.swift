import SwiftUI
import AppKit

struct DebugView: View {
    @StateObject private var debugState = DebugState.shared
    @State private var searchText = ""

    var filteredMessages: [DebugMessage] {
        let messages = debugState.filteredMessages()
        if searchText.isEmpty {
            return messages
        }
        return messages.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 工具栏
                HStack(spacing: 12) {


                    // 消息类型过滤
                    Picker("类型", selection: $debugState.selectedMessageType) {
                        Text("全部").tag(Optional<DebugMessageType>.none)
                        ForEach(DebugMessageType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Optional.some(type))
                        }
                    }
                    .frame(width: 100)

                    // 搜索框
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .font(.system(size: 12))

                    Toggle("详情", isOn: Binding(
                        get: { debugState.showDetails },
                        set: { newValue in
                            withAnimation {
                                debugState.showDetails = newValue
                            }
                            // 只保存显示详情的状态
                            UserDefaults.standard.set(newValue, forKey: "debug_window_show_details")
                        }
                    ))
                    .toggleStyle(.switch)

                    // 添加吸附按钮
                    Toggle("吸附", isOn: $debugState.isAttached)
                        .toggleStyle(.switch)

                    Button(action: {
                        debugState.clearMessages()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // 消息列表
                if filteredMessages.isEmpty {
                    Spacer()
                    Text("暂无调试信息")
                        .foregroundColor(.gray)
                        .font(.system(size: 13))
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(filteredMessages) { message in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(message.formattedMessage)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(message.type.color)
                                            .textSelection(.enabled)

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
        }
        .frame(minWidth: 400, minHeight: 300)
        .background(WindowDragHandler())
        .task {
            WindowConfig.configureDebugWindow()
        }
    }
}

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
