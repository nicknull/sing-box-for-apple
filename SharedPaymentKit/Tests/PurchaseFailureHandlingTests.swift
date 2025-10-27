//
//  PurchaseFailureHandlingTests.swift
//  SharedPaymentKit
//
//  测试购买失败处理和官网引导功能
//

import Foundation

struct PurchaseFailureHandlingTests {

    /// 测试不同错误类型的用户友好消息
    static func testErrorMessages() {
        let testCases: [(PurchaseXException, String)] = [
            (.purchaseException, "购买过程中出现错误"),
            (.userNotAllowedToMakePurchases, "当前账户不允许进行购买，请检查设备限制设置"),
            (.paymentMethodNotAvailable, "支付方式不可用，请检查您的支付设置"),
            (.networkError("连接超时"), "网络连接出现问题，请检查网络后重试"),
            (.unknownError("未知错误"), "支付时遇到未知错误")
        ]

        for (error, expectedMessage) in testCases {
            let actualMessage = error.userFriendlyMessage()
            print("✅ 错误类型: \(error)")
            print("   期望消息: \(expectedMessage)")
            print("   实际消息: \(actualMessage)")
            print("   测试结果: \(actualMessage == expectedMessage ? "通过" : "失败")")
            print()
        }
    }

    /// 测试官网引导选项的显示逻辑
    static func testWebsiteGuidanceLogic() {
        let shouldShowCases: [PurchaseXException] = [
            .purchaseException,
            .userNotAllowedToMakePurchases,
            .paymentMethodNotAvailable,
            .networkError("连接失败"),
            .unknownError("未知错误")
        ]

        let shouldNotShowCases: [PurchaseXException] = [
            .purchaseInProgressException,
            .transactionVerificationFailed
        ]

        print("=== 应该显示官网引导的错误类型 ===")
        for error in shouldShowCases {
            let shouldShow = error.shouldShowWebsiteOption()
            print("✅ \(error): \(shouldShow ? "显示" : "不显示") - \(shouldShow ? "通过" : "❌ 失败")")
        }

        print("\n=== 不应该显示官网引导的错误类型 ===")
        for error in shouldNotShowCases {
            let shouldShow = error.shouldShowWebsiteOption()
            print("✅ \(error): \(shouldShow ? "显示" : "不显示") - \(!shouldShow ? "通过" : "❌ 失败")")
        }
    }

    /// 运行所有测试
    static func runAllTests() {
        print("🧪 开始测试购买失败处理功能\n")

        print("📝 测试错误消息")
        testErrorMessages()

        print("🔗 测试官网引导逻辑")
        testWebsiteGuidanceLogic()

        print("✅ 所有测试完成")
    }
}

// MARK: - 模拟购买失败场景的工具方法
extension PurchaseFailureHandlingTests {

    /// 模拟各种购买失败场景
    static func simulateFailureScenarios() -> [PurchaseFailureInfo] {
        return [
            PurchaseFailureInfo(
                error: .userNotAllowedToMakePurchases,
                productId: "com.gy.iflash.bcup.month"
            ),
            PurchaseFailureInfo(
                error: .paymentMethodNotAvailable,
                productId: "com.gy.iflash.ccup.year"
            ),
            PurchaseFailureInfo(
                error: .networkError("网络连接超时"),
                productId: "com.gy.iflash.dcup.month"
            ),
            PurchaseFailureInfo(
                error: .purchaseException,
                productId: "com.gy.iflash.zcup.year"
            )
        ]
    }
}