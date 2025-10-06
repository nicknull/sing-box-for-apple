import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


public struct ToastNotification: View {
    public enum DisplayMode {
        case banner
        case hud
    }

    public enum AlertType: Equatable {
        case regular
        case complete(Color)
        case error(Color)
        case systemImage(String, Color)
    }

    struct Configuration: Equatable {
        var displayMode: DisplayMode
        var type: AlertType
        var title: String?
        var subTitle: String?
    }

    var configuration: Configuration

    public init(
        displayMode: DisplayMode = .banner,
        type: AlertType = .regular,
        title: String? = nil,
        subTitle: String? = nil
    ) {
        configuration = Configuration(
            displayMode: displayMode,
            type: type,
            title: title,
            subTitle: subTitle
        )
    }

    public var body: some View {
        ToastNotificationView(configuration: configuration)
    }
}

private struct ToastNotificationView: View {
    let configuration: ToastNotification.Configuration

    var body: some View {
        HStack(spacing: 12) {
            if let icon = iconInfo {
                Image(systemName: icon.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(icon.color)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: configuration.subTitle == nil ? 0 : 4) {
                if let title = configuration.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }
                if let subTitle = configuration.subTitle {
                    Text(subTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.toastBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12))
        )
        .foregroundColor(.primary)
        .accessibilityElement(children: .combine)
    }

    private var iconInfo: (name: String, color: Color)? {
        switch configuration.type {
        case .regular:
            return nil
        case .complete(let color):
            return ("checkmark.circle.fill", color)
        case .error(let color):
            return ("xmark.octagon.fill", color)
        case .systemImage(let name, let color):
            return (name, color)
        }
    }
}

private struct ToastNotificationModifier: ViewModifier {
    @Binding var isPresenting: Bool
    var duration: Double
    var tapToDismiss: Bool
    var closeOnTapOutside: Bool
    let builder: () -> ToastNotification

    @State private var dismissTask: DispatchWorkItem?

    func body(content: Content) -> some View {
        ZStack {
            content
            overlayLayer
        }
        .animation(.easeInOut(duration: 0.2), value: isPresenting)
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if isPresenting {
            GeometryReader { proxy in
                let toast = builder()
                ToastOverlay(
                    configuration: toast.configuration,
                    tapToDismiss: tapToDismiss,
                    closeOnTapOutside: closeOnTapOutside,
                    dismissAction: dismiss
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .transition(transition(for: toast.configuration.displayMode))
                .onAppear(perform: scheduleDismiss)
                .onDisappear(perform: cancelDismiss)
            }
        }
    }

    private func scheduleDismiss() {
        guard duration > 0 else { return }
        dismissTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation {
                isPresenting = false
            }
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    private func cancelDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func dismiss() {
        withAnimation {
            isPresenting = false
        }
    }

    private func transition(for mode: ToastNotification.DisplayMode) -> AnyTransition {
        switch mode {
        case .hud:
            return AnyTransition.opacity.combined(with: .scale(scale: 0.9, anchor: .center))
        case .banner:
            return AnyTransition.move(edge: .bottom).combined(with: .opacity)
        }
    }
}

private struct ToastOverlay: View {
    let configuration: ToastNotification.Configuration
    let tapToDismiss: Bool
    let closeOnTapOutside: Bool
    let dismissAction: () -> Void

    var body: some View {
        ZStack {
            if closeOnTapOutside {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissAction)
            }

            switch configuration.displayMode {
            case .hud:
                ToastNotificationView(configuration: configuration)
                    .onTapGesture { if tapToDismiss { dismissAction() } }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .banner:
                VStack {
                    Spacer()
                    ToastNotificationView(configuration: configuration)
                        .onTapGesture { if tapToDismiss { dismissAction() } }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .allowsHitTesting(tapToDismiss || closeOnTapOutside)
    }
}

public extension View {
    func toast(
        isPresenting: Binding<Bool>,
        duration: Double = 2.0,
        tapToDismiss: Bool = true,
        closeOnTapOutside: Bool? = nil,
        @ViewBuilder content: @escaping () -> ToastNotification
    ) -> some View {
        modifier(
            ToastNotificationModifier(
                isPresenting: isPresenting,
                duration: duration,
                tapToDismiss: tapToDismiss,
                closeOnTapOutside: closeOnTapOutside ?? tapToDismiss,
                builder: content
            )
        )
    }
}

private extension Color {
    static var toastBackground: Color {
        #if os(iOS) || os(tvOS)
        return Color(UIColor.secondarySystemBackground.withAlphaComponent(0.92))
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor).opacity(0.92)
        #else
        return Color(.sRGB, white: 0.15, opacity: 0.9)
        #endif
    }
}
