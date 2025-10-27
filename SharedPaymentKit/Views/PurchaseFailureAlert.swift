//
//  PurchaseFailureAlert.swift
//  SharedPaymentKit
//
//  支付失败时的引导弹窗，提供前往官网购买的选项
//

import SwiftUI
import Defaults

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct PurchaseFailureAlert {
    let error: PurchaseXException
    let onRetry: (() -> Void)?
    let onGoToWebsite: (() -> Void)?
    let onDismiss: () -> Void

    func makeAlert() -> Alert {
        let errorMessage = error.userFriendlyMessage()
        let shouldShowWebsiteOption = error.shouldShowWebsiteOption()

        if shouldShowWebsiteOption {
            // 显示包含官网引导的 Alert
            return Alert(
                title: Text("购买失败"),
                message: Text("\(errorMessage)\n\n您也可以前往官网进行购买"),
                primaryButton: .default(
                    Text("前往官网"),
                    action: {
                        onGoToWebsite?()
                    }
                ),
                secondaryButton: .cancel(
                    Text("取消"),
                    action: onDismiss
                )
            )
        } else {
            // 只显示重试选项
            return Alert(
                title: Text("购买失败"),
                message: Text(errorMessage),
                primaryButton: .default(
                    Text("重试"),
                    action: {
                        onRetry?()
                    }
                ),
                secondaryButton: .cancel(
                    Text("取消"),
                    action: onDismiss
                )
            )
        }
    }
}

// MARK: - 购买页面使用的扩展
extension View {
    /// 显示购买失败的 Alert，自动处理官网引导
    func purchaseFailureAlert(
        isPresented: Binding<Bool>,
        error: PurchaseXException?,
        onRetry: (() -> Void)? = nil,
        onGoToWebsite: (() -> Void)? = nil
    ) -> some View {
        self.alert(isPresented: isPresented) {
            guard let error = error else {
                return Alert(
                    title: Text("错误"),
                    message: Text("未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }

            return PurchaseFailureAlert(
                error: error,
                onRetry: onRetry,
                onGoToWebsite: onGoToWebsite ?? {
                    openWebsitePurchasePage()
                }
            ) {
                // onDismiss
            }.makeAlert()
        }
    }
}

// MARK: - 打开官网购买页面的全局函数
private func openWebsitePurchasePage() {
    let websiteURL = "\(Defaults[.host])/#/buy"

    if let url = URL(string: websiteURL) {
        #if os(iOS) || os(tvOS)
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - 购买失败信息模型
struct PurchaseFailureInfo {
    let error: PurchaseXException
    let productId: String
    let timestamp: Date = Date()

    var shouldShowWebsiteGuidance: Bool {
        error.shouldShowWebsiteOption()
    }

    var userFriendlyMessage: String {
        error.userFriendlyMessage()
    }
}