//
//  ToastModifier.swift
//  sing-box
//
//  Created by xiaokang chen on 2025/6/28.
//

import SwiftUI
import SwiftUI

struct ToastKit {
    
    struct ToastModifier<ToastContent: View>: ViewModifier {
        @Binding var isPresented: Bool
        var duration: Double
        var position: Alignment
        var animation: Animation
        var transition: AnyTransition
        var toastContent: () -> ToastContent
        
        func body(content: Content) -> some View {
            ZStack(alignment: position) {
                content
                
                if isPresented {
                    toastContent()
                        .transition(transition)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(animation) {
                                    isPresented = false
                                }
                            }
                        }
                        .padding(.bottom, position == .bottom ? 50 : 0)
                }
            }
            .animation(animation, value: isPresented)
        }
    }
    
    // MARK: Toast 样式
    
    static func successToast(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    
    static func errorToast(_ message: String) -> some View {
        HStack {
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(.red)
            Text(message)
        }
        .padding()
        .background(Color.black.opacity(0.85))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    
    static func loadingToast(_ message: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text(message)
        }
        .frame(width: 100, height: 100)
        .padding()
        .background(Color.black.opacity(0.85))
        .foregroundColor(.white)
        .cornerRadius(12)
    }
}

extension View {
    
    /// 通用 Toast 接口
    func toastKit<Content: View>(
        isPresented: Binding<Bool>,
        duration: Double = 2.0,
        position: Alignment = .bottom,
        animation: Animation = .easeInOut,
        transition: AnyTransition = .move(edge: .bottom).combined(with: .opacity),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(ToastKit.ToastModifier(
            isPresented: isPresented,
            duration: duration,
            position: position,
            animation: animation,
            transition: transition,
            toastContent: content)
        )
    }
    
    /// successToast 快捷方法
    func successToast(
        isPresented: Binding<Bool>,
        message: String,
        duration: Double = 2.0,
        position: Alignment = .bottom,
        animation: Animation = .easeInOut,
        transition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    ) -> some View {
        self.toastKit(
            isPresented: isPresented,
            duration: duration,
            position: position,
            animation: animation,
            transition: transition
        ) {
            ToastKit.successToast(message)
        }
    }
    
    /// errorToast 快捷方法
    func errorToast(
        isPresented: Binding<Bool>,
        message: String,
        duration: Double = 2.0,
        position: Alignment = .bottom,
        animation: Animation = .easeInOut,
        transition: AnyTransition = .move(edge: .bottom).combined(with: .opacity)
    ) -> some View {
        self.toastKit(
            isPresented: isPresented,
            duration: duration,
            position: position,
            animation: animation,
            transition: transition
        ) {
            ToastKit.errorToast(message)
        }
    }
    

    func loadingHUD(
        isPresented: Binding<Bool>,
        message: String,
        position: Alignment = .center,
        animation: Animation = .easeInOut,
        transition: AnyTransition = .opacity
    ) -> some View {
        self.toastKit(
            isPresented: isPresented,
            duration: 99999,
            position: position,
            animation: animation,
            transition: transition
        ) {
            ToastKit.loadingToast(message)
        }
    }

}
