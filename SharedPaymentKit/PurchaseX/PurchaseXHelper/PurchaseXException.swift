//
//  PurchaseException.swift
//  PurchaseX
//
//  Created by shenjie on 2021/7/23.
//

import Foundation

public enum PurchaseXException: Error, Equatable {
    case purchaseException
    case purchaseInProgressException
    case transactionVerificationFailed
    case userNotAllowedToMakePurchases
    case paymentMethodNotAvailable
    case networkError(String)
    case unknownError(String)

    public func shortDescription() -> String {
        switch self {
        case .purchaseException:
            return "Exception: StoreKit throw an exception while processing a purchase"
        case .purchaseInProgressException:
            return "Exception: You can't start another purchase yet, one is already in process"
        case .transactionVerificationFailed:
            return "Exception: A transaction failed Storekit's verification"
        case .userNotAllowedToMakePurchases:
            return "Exception: User is not allowed to make purchases"
        case .paymentMethodNotAvailable:
            return "Exception: Payment method not available or configured"
        case .networkError(let description):
            return "Exception: Network error - \(description)"
        case .unknownError(let description):
            return "Exception: Unknown error - \(description)"
        }
    }

    /// 获取用户友好的错误信息
    public func userFriendlyMessage() -> String {
        switch self {
        case .purchaseException:
            return "购买过程中出现错误"
        case .purchaseInProgressException:
            return "已有购买正在进行中，请稍后再试"
        case .transactionVerificationFailed:
            return "交易验证失败"
        case .userNotAllowedToMakePurchases:
            return "当前账户不允许进行购买，请检查设备限制设置"
        case .paymentMethodNotAvailable:
            return "支付方式不可用，请检查您的支付设置"
        case .networkError(_):
            return "网络连接出现问题，请检查网络后重试"
        case .unknownError(_):
            return "支付时遇到未知错误"
        }
    }

    /// 判断是否应该显示官网引导选项
    public func shouldShowWebsiteOption() -> Bool {
        switch self {
        case .purchaseInProgressException:
            return false // 购买进行中，不需要引导
        case .transactionVerificationFailed:
            return false // 验证失败，不是支付问题
        default:
            return true // 其他情况都可以引导到官网
        }
    }
}
