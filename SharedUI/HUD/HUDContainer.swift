import SwiftUI

/// 在任意视图外部包裹 `HUDContainer`，即可显示全局 HUD。
public struct HUDContainer<Content: View>: View {
    @ObservedObject private var manager = HUDManager.shared
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
            if let style = manager.style {
                hudView(for: style)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.style != nil)
    }

    @ViewBuilder
    private func hudView(for style: HUDStyle) -> some View {
        switch style {
        case let .loading(message):
            HUDVisual(style: style) {
                ProgressView()
                    .progressViewStyle(.circular)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
            }

        case let .success(message):
            HUDVisual(style: style) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
            }

        case let .failure(message):
            HUDVisual(style: style) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.red)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

private struct HUDVisual<Content: View>: View {
    let style: HUDStyle
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
}
