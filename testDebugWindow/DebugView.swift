import SwiftUI

class DebugState: ObservableObject {
    static let shared = DebugState()
    @Published var debugMessages: [String] = []
    @Published var isWindowOpen = false

    func addMessage(_ message: String) {
        DispatchQueue.main.async {
            self.debugMessages.append("[\(Date().formatted())] \(message)")
        }
    }
}

struct DebugView: View {
    @StateObject private var debugState = DebugState.shared
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack {
            HStack {
                Text("调试窗口")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    debugState.debugMessages.removeAll()
                }
            }
            .padding()

            if debugState.debugMessages.isEmpty {
                Text("暂无调试信息")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(debugState.debugMessages, id: \.self) { message in
                    Text(message)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onDisappear {
            debugState.isWindowOpen = false
        }
    }
}