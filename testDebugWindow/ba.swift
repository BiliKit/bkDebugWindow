import SwiftUI


/// 窗口组
@MainActor
public struct WindowGroupWithDebugWindow<Content: View>: Scene {
    private let content: Content
    private let id: String?

    public init(id: String? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.id = id
    }

    public var body: some Scene {
        WindowGroup {
            MainContentView(content: content)
        }
    }
}

/// 主内容视图
@MainActor
private struct MainContentView<Content: View>: View {
    @StateObject private var manager = baWindowManager.shared
    let content: Content

    var body: some View {
        content
            .frame(minWidth: 400, minHeight: 500)
            .onAppear {
                setupDebugWindow()
            }
    }

    private func setupDebugWindow() {
        let debugWindow = baDebugWindowDelegate.shared.createDebugWindow()
        manager.debugWindow = debugWindow
        manager.mainWindow = NSApplication.shared.windows.first

        Task { @MainActor in
            baDebugState.shared.system("debug window created")

            // 设置调试窗口初始位置和绑定关系
            if let mainWindow = manager.mainWindow {
                mainWindow.addChildWindow(debugWindow, ordered: .above)
            }
        }
    }
}
