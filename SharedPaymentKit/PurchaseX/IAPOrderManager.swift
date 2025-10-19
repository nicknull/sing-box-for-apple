//
//  IAPOrderManager.swift
//  SFI
//
//  Created by Claude Code
//

import Foundation
import StoreKit


/// IAP 订单管理器，负责处理订单上报
class IAPOrderManager {

    /// 上报订单到后端
    /// - Parameters:
    ///   - transaction: StoreKit Transaction 对象
    ///   - completion: 完成回调
    static func reportOrder(transaction: StoreKit.Transaction, tradeNo: String? = nil, appAccountToken: String? = nil, completion: ((Bool, String?) -> Void)? = nil) {
        let transactionID = String(transaction.id)
        let originalTransactionID = String(transaction.originalID)
        let productID = transaction.productID

        print("📦 上报 IAP 订单:")
        print("  - Transaction ID: \(transactionID)")
        print("  - Original Transaction ID: \(originalTransactionID)")
        print("  - Product ID: \(productID)")

        // 调用后端 API
        NetworkService.shared.request(
            AQAPIService.reportIAPOrder(
                transactionID: transactionID,
                originalTransactionID: originalTransactionID,
                productID: productID,
                tradeNo: tradeNo,
                appAccountToken: appAccountToken
            ),
            decodeTo: IAPOrderResponse.self
        ) { result in
            switch result {
            case .success(let payload):
                if payload.context.httpStatusCode == 200 {
                    print("✅ 订单上报成功")
                    completion?(true, nil)
                } else {
                    let errorMsg = payload.context.message ?? "订单上报失败"
                    print("❌ 订单上报失败: \(errorMsg)")
                    completion?(false, errorMsg)
                }

            case .failure(let error):
                let errorMsg = error.message
                print("❌ 订单上报失败: \(errorMsg)")
                completion?(false, errorMsg)
            }
        }
    }

    /// 恢复购买：上传交易快照
    static func restorePurchases(appAccountToken: String, transactions: [[String: Any]], completion: ((Bool, String?) -> Void)? = nil) {
        NetworkService.shared.request(
            AQAPIService.restoreIAPOrders(appAccountToken: appAccountToken, transactions: transactions),
            decodeTo: IAPOrderResponse.self
        ) { result in
            switch result {
            case .success(let payload):
                if payload.context.httpStatusCode == 200 {
                    completion?(true, nil)
                } else {
                    completion?(false, payload.context.message ?? "恢复失败")
                }

            case .failure(let error):
                completion?(false, error.message)
            }
        }
    }
}

/// IAP 订单响应模型
struct IAPOrderResponse: Codable {
    let order_id: String?
    let message: String?
}

// 预下单响应模型
struct PrepareIAPOrderResponse: Codable {
    let trade_no: String?
    let plan_id: Int?
    let period: String?
    let order_type: Int?
}
