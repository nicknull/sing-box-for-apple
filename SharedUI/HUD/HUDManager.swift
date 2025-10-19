import SwiftUI

/// HUD 展示的样式
public enum HUDStyle: Equatable {
    case loading(message: String?)
    case success(message: String?)
    case failure(message: String?)
}

/// 全局 HUD 管理器，负责跟踪当前 HUD 状态
@MainActor
public final class HUDManager: ObservableObject {
    public static let shared = HUDManager()

    @Published public private(set) var style: HUDStyle?

    private init() {}

    public func showLoading(_ message: String? = nil) {
        style = .loading(message: message)
    }

    public func showSuccess(_ message: String? = nil, autoDismiss after: TimeInterval = 1.2) {
        style = .success(message: message)
        scheduleAutoDismiss(after: after)
    }

    public func showFailure(_ message: String? = nil, autoDismiss after: TimeInterval = 1.6) {
        style = .failure(message: message)
        scheduleAutoDismiss(after: after)
    }

    public func dismiss() {
        style = nil
    }

    private func scheduleAutoDismiss(after: TimeInterval) {
        guard after > 0 else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
            await self?.dismiss()
        }
    }
}

public extension HUDManager {
    static func showLoading(_ message: String? = nil) {
        Task { await shared.showLoading(message) }
    }

    static func showSuccess(_ message: String? = nil) {
        Task { await shared.showSuccess(message) }
    }

    static func showFailure(_ message: String? = nil) {
        Task { await shared.showFailure(message) }
    }

    static func dismiss() {
        Task { await shared.dismiss() }
    }
}
