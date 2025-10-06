//
//  SharedPaymentKit.swift
//  sing-box-for-apple
//
//  支付相关共享模块入口
//

import Foundation
import StoreKit

public enum SharedPaymentKit {
    /// 工厂方法：创建统一的内购管理器
    public static func makePurchaseManager() -> PurchaseXManager {
        PurchaseXManager()
    }

    /// 便捷方法：触发商品列表拉取
    @MainActor
    public static func preloadProducts(_ identifiers: [String]) async -> [Product]? {
        let manager = PurchaseXManager()
        return await manager.requestProductsFromAppstore(productIds: identifiers)
    }
}
