import SwiftUI
import Combine

final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
            .map { $0.height }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: &self.$keyboardHeight)
    }
}

struct KeyboardAvoiding: ViewModifier {
    @ObservedObject var keyboard: KeyboardObserver

    func body(content: Content) -> some View {
        content
            .padding(.bottom, max(0, keyboard.keyboardHeight - 10))
            .animation(.easeOut(duration: 0.25), value: keyboard.keyboardHeight)
    }
}

extension View {
    func keyboardAvoiding(_ observer: KeyboardObserver = KeyboardObserver()) -> some View {
        self.modifier(KeyboardAvoiding(keyboard: observer))
    }
}

