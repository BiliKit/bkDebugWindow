import SwiftUI
import AppKit

extension NSWindow {
    func hideControls() {
        styleMask.remove(.closable)
        styleMask.remove(.miniaturizable)
        styleMask.remove(.resizable)
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
    }
}

struct HideControlsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                EffectView()
            }
    }
}

private struct EffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.hideControls()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func hideWindowControls() -> some View {
        modifier(HideControlsModifier())
    }
}

struct WindowStyleModifier: ViewModifier {
    let style: NSWindow.StyleMask

    func body(content: Content) -> some View {
        content
            .task {
                if let window = WindowAccessor.getWindow() {
                    // 确保在主线程中修改窗口属性
                    DispatchQueue.main.async {
                        window.styleMask = style
                    }
                }
            }
    }
}