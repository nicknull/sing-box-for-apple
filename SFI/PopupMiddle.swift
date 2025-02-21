//
//  PopupMiddle.swift
//  SFI
//
//  Created by xiaokang chen on 2024/8/30.
//

import SwiftUI
class SomeItem: Equatable {
    
    let value: String
    
    init(value: String) {
        self.value = value
    }
    
    static func == (lhs: SomeItem, rhs: SomeItem) -> Bool {
        lhs.value == rhs.value
    }
}
struct PopupMiddle: View {

//    let item: SomeItem
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image("winner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 226, maxHeight: 226)
            
            Text("使用须知")
                .foregroundColor(.black)
                .font(.system(size: 24))
                .padding(.top, 12)
            
            Text("为确保服务稳定性，我们将通过邮件更新地址信息。请授权我们访问您的邮箱，以便在您遇到登录、注册或更新问题时，我们能够迅速发送修复邮件。")
                .foregroundColor(.black)
                .font(.system(size: 16))
                .opacity(0.6)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            Button {
                onClose()
            } label: {
                Text("确定")
                    .font(.system(size: 18, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .foregroundColor(.white)
                    .background(Color(hexString: "#9265F8"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 37, leading: 24, bottom: 40, trailing: 24))
        .background(Color.white.cornerRadius(20))
        .padding(.horizontal, 40)
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 0)
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 0)
    }
}
