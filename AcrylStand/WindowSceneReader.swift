#if canImport(UIKit)
import UIKit
import SwiftUI

struct WindowSceneReader<Content: View>: View {
    var content: (@escaping () -> UIWindowScene?, UIWindow?) -> Content
    @State private var window: UIWindow?

    var body: some View {
        content({ Self.windowScene(for: window) }, window)
            .overlay { WindowReadingView(parentWindow: $window).frame(width: 0, height: 0) }
    }

    private static func windowScene(for window: UIWindow? = nil) -> UIWindowScene? {
        window.flatMap { window in
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.windows.contains(window) }
        }
    }

    struct WindowReadingView: UIViewRepresentable {
        @Binding var parentWindow: UIWindow?
        func makeUIView(context: Context) -> UIView { WindowReadingUIView(parentWindow: _parentWindow) }
        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    class WindowReadingUIView: UIView {
        @Binding var parentWindow: UIWindow?
        init(parentWindow: Binding<UIWindow?>) {
            self._parentWindow = parentWindow
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window else {
                parentWindow = nil
                return
            }
            Task.detached { @Sendable @MainActor in
                defer { self.parentWindow = window }
                let start = Date()
                let timeout: TimeInterval = 10
                while WindowSceneReader.windowScene(for: window) == nil, Date().timeIntervalSince(start) < timeout  {
                    try! await Task.sleep(for: .milliseconds(100))
                }
            }
        }
    }
}
#endif
