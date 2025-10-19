//
//  PurchaseHelper.swift
//  PurchaseX
//
//  Created by shenjie on 2021/7/22.
//

import Foundation
import StoreKit

public class PurchaseXManager: NSObject, ObservableObject {

    // MARK: Public Property
    /// Array of products retrieved from AppleStore
    @Published public var products: [Product]?

    /// Handle for App Store transactions
    private var transactionListener: Task<Void, Error>? = nil

    /// Purchase state
    private var purchaseState: PurchaseXState = .notStarted

    /// 购买成功回调，用于通知后端
    public var onPurchaseSuccess: ((Transaction) -> Void)?
    
    /// Array of consumable products
    public var consumableProducts: [Product]? {
        guard products != nil else {
            return nil
        }
        
        return products?.filter({ product in
            product.type == .consumable
        })
    }
    
    /// Array of nonConsumbale products
    public var nonConsumbaleProducts: [Product]? {
        guard products != nil else {
            return nil
        }
        
        return products?.filter({ product in
            product.type == .nonConsumable
        })
    }
    
    /// Array of subscriptio products
    public var subscriptionProducts: [Product]? {
        guard products != nil else {
            return nil
        }
        
        return products?.filter({ product in
            product.type == .autoRenewable
        })
    }
    
    /// Array of nonSubscription products
    public var nonSubscriptionProducts: [Product]? {
        guard products != nil else {
            return nil
        }
        
        return products?.filter({ product in
            product.type == .nonRenewable
        })
    }
        
    // MARK: - Initialization
    public override init() {
        super.init()
        // Listen for App Store transactions
        transactionListener = handTransaction()
    }

    deinit {
        transactionListener?.cancel()
    }
    
    
    // MARK: - requestProductsFromAppstore
    /// - Request products form appstore
    /// - Parameter completion: a closure that will be called when the results returned from the appstore
    @MainActor public func requestProductsFromAppstore(productIds: [String]) async -> [Product]? {
        // 记录产品加载开始
        SharedAnalyticsKit.shared.logCustomEvent(
            name: "iap_products_load_started",
            parameters: [
                "product_ids": productIds.joined(separator: ","),
                "product_count": productIds.count
            ]
        )

        do {
            products = try await Product.products(for: Set.init(productIds))

            // 记录产品加载成功
            SharedAnalyticsKit.shared.logCustomEvent(
                name: "iap_products_load_success",
                parameters: [
                    "requested_count": productIds.count,
                    "loaded_count": products?.count ?? 0,
                    "loaded_products": (products?.map { $0.id } ?? []).joined(separator: ",")
                ]
            )

            return products
        } catch {
            // 记录产品加载失败
            SharedAnalyticsKit.shared.logCustomEvent(
                name: "iap_products_load_failed",
                parameters: [
                    "product_ids": productIds.joined(separator: ","),
                    "error": error.localizedDescription
                ]
            )
             SharedAnalyticsKit.shared.logError(error: error, context: "iap_products_load")

            products = nil
            return nil
        }
    }
    
    // MARK: - purchase
    /// Start the process to purchase a product.
    /// - Parameters:
    ///   - product: Product object
    ///   - options: Purchase options
    ///   - userID: 用户 ID，用于绑定订单到用户账号
    public func purchase(product: Product, options: Set<Product.PurchaseOption> = [], userID: String? = nil) async throws -> (transaction: Transaction?, purchaseState: PurchaseXState){
        guard purchaseState != .inProgress else {
            throw PurchaseXException.purchaseInProgressException
        }

        // 记录购买开始事件
         SharedAnalyticsKit.shared.logCustomEvent(name: "iap_purchase_started", parameters: [
             "product_id": product.id,
             "product_type": "\(product.type)",
             "price": NSDecimalNumber(decimal: product.price).doubleValue,
             "currency": product.priceFormatStyle.currencyCode,
             "user_id": userID ?? "unknown"
         ])

        purchaseState = .inProgress

        // 创建购买选项，包含用户 ID
        var purchaseOptions = options

        // 如果提供了用户 ID，使用 appAccountToken 绑定用户
        if let userID = userID, let uuid = createAppAccountToken(from: userID) {
            purchaseOptions.insert(.appAccountToken(uuid))
        }

        // Start a purchase transaction
        guard let result = try? await product.purchase(options: purchaseOptions) else {
            purchaseState = .failed

            // 记录购买失败事件
             SharedAnalyticsKit.shared.logIAPPurchase(
                 productId: product.id,
                 success: false,
                 amount: NSDecimalNumber(decimal: product.price).doubleValue
             )

            throw PurchaseXException.purchaseException
        }
        
        switch result {
        case .success(let verificationResult):
            let checkResult = checkTransactionVerificationResult(result: verificationResult)
            if !checkResult.verified {
                purchaseState = .failedVerification

                // 记录验证失败事件
                 SharedAnalyticsKit.shared.logIAPPurchase(
                     productId: product.id,
                     success: false,
                     amount: NSDecimalNumber(decimal: product.price).doubleValue,
                     transactionId: checkResult.transaction.id.description
                 )
                 SharedAnalyticsKit.shared.logCustomError(
                     message: "IAP transaction verification failed",
                     context: "iap_purchase"
                 )

                throw PurchaseXException.transactionVerificationFailed
            }

            let validatedTransaction = checkResult.transaction

            // 记录购买成功事件
             SharedAnalyticsKit.shared.logIAPPurchase(
                 productId: product.id,
                 success: true,
                 amount: NSDecimalNumber(decimal: product.price).doubleValue,
                 transactionId: validatedTransaction.id.description
             )

            // 触发购买成功回调，用于上报后端（由上层负责 finish）
            onPurchaseSuccess?(validatedTransaction)

            // Because consumable's transaction are not stored in the receipt, So treat it differently.
            if validatedTransaction.productType == .consumable {
                if !PXDataPersistence.purchase(productId: product.id){
                    PXLog.event(.consumableKeychainError)
                }
            }
            purchaseState = .complete
            return (transaction: validatedTransaction, purchaseState: .complete)
        case .userCancelled:
            purchaseState = .cancelled

            // 记录用户取消购买事件
             SharedAnalyticsKit.shared.logCustomEvent(name: "iap_purchase_cancelled", parameters: [
                 "product_id": product.id,
                 "price": NSDecimalNumber(decimal: product.price).doubleValue
             ])

            return (transaction: nil, purchaseState: .cancelled)
        case .pending:
            purchaseState = .pending

            // 记录购买待处理事件
             SharedAnalyticsKit.shared.logCustomEvent(name: "iap_purchase_pending", parameters: [
                 "product_id": product.id,
                 "price": NSDecimalNumber(decimal: product.price).doubleValue
             ])

            return (transaction: nil, purchaseState: .pending)
        default:
            purchaseState = .unknown

            // 记录未知状态事件
             SharedAnalyticsKit.shared.logCustomEvent(name: "iap_purchase_unknown", parameters: [
                 "product_id": product.id,
                 "price": NSDecimalNumber(decimal: product.price).doubleValue
             ])

            return (transaction: nil, purchaseState: .unknown)
        }
    }
    
    /// Returns all productID  the user is currently entitled to, but without consumables products.
    /// - Returns: A set of productID
    public func currentEntitlements() async -> Set<String> {
        var entitledProductIds = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                entitledProductIds.insert(transaction.productID)
            }
        }
        
        return entitledProductIds
    }

    /// 获取用于恢复购买的交易快照（简化：当前有效的交易）
    /// 返回每笔交易的必要字段供后端校验与补单
    public func transactionsSnapshot(appAccountToken: String? = nil, limit: Int = 20) async -> [[String: Any]] {
        var list: [[String: Any]] = []
        var seen = Set<String>()
        let expectedToken = appAccountToken.flatMap { createAppAccountToken(from: $0)?.uuidString }

        func appendTransaction(_ transaction: Transaction) {
            let transactionID = String(transaction.id)
            guard !seen.contains(transactionID) else { return }
            seen.insert(transactionID)

            if let expectedToken = expectedToken,
               let actualToken = transaction.appAccountToken?.uuidString,
               actualToken != expectedToken {
                return
            }

            var item: [String: Any] = [
                "transaction_id": transactionID,
                "original_transaction_id": String(transaction.originalID),
                "product_id": transaction.productID,
                "revoked": transaction.revocationDate != nil
            ]

            if let token = transaction.appAccountToken?.uuidString {
                item["app_account_token"] = token
            }

            list.append(item)
        }

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                appendTransaction(transaction)
            }
        }

        if list.isEmpty {
            for await result in Transaction.all {
                guard list.count < limit else { break }
                if case .verified(let transaction) = result {
                    guard transaction.productType != .consumable else { continue }
                    guard transaction.revocationDate == nil else { continue }
                    appendTransaction(transaction)
                }
            }
        }

        return list
    }
    
    // MARK: - extend function interface
    
    /// True if purchased
    /// - Parameter productId: productid
    /// - Returns:true if purchased
    public func isPurchased(productId: String) async throws -> Bool {

        guard let product  = product(from: productId) else {
            return false
        }

        if product.type == .consumable {
            return PXDataPersistence.getProductCount(productId: productId) > 0
        }
    
        guard let currentEntitlement = await Transaction.currentEntitlement(for: productId) else {
            return false
        }
        
        let result = checkTransactionVerificationResult(result: currentEntitlement)
        if !result.verified {
            throw PurchaseXException.transactionVerificationFailed
        }
        
        return result.transaction.revocationDate == nil && !result.transaction.isUpgraded
    }
    
    /// Get a 'Product' object associated with productId
    /// - Parameter productId:
    /// - Returns:A Product object
    public func product(from productId: String) -> Product? {
        guard hasProducts() else {
            return nil
        }
        
        let matchProduct = products!.filter { product in
            product.id == productId
        }
        
        guard matchProduct.count == 1 else {
            return nil
        }
        
        return matchProduct.first
    }
    
    /// True if appstore products have been retrived from appstore
    /// - Returns: True or false
    public func hasProducts() -> Bool {
        guard products != nil else {
            return false
        }

        return products!.count > 0 ? true : false
    }
    
    
    /// Returns all subscription productID and nonSubscription productID the user is currently entitled to
    /// - Parameter onlyRenewable: If true return all subscription productID
    /// - Returns: A array of productID
    public func activeSubscriptions(onlyRenewable: Bool = true) async -> [String] {
        
        var productId = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable || (!onlyRenewable && transaction.productType ==  .nonRenewable){
                    productId.insert(transaction.productID)
                }
            }
        }
        return Array(productId)
    }
    
    /// Returns all NonConsumable productID the user is currently entitled to
    /// - Returns: A array of NonConsumable productID
    public func purchasedNonConsumable() async -> [String] {
        var productId = Set<String>()
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .nonConsumable {
                    productId.insert(transaction.productID)
                }
            }
        }
        return Array(productId)
    }
    
    /// Sync signed transaction and renewal info with the App Store.
    public func restorePurchase() async throws {
        try await AppStore.sync()
    }
    
    /// Present a UI and display all currently-subscribed products
    /// - Parameter scene: UIWindowScene object
    ///
    ///  
//    public func showManageSubscriptions(in scene: UIWindowScene) async throws {
//        try await AppStore.showManageSubscriptions(in: scene)
//    }
    
    /// Display the refund request sheet
    /// - Parameters:
    ///   - productId: productId
    ///   - scene: UIWindowScene object
    /// - Returns: True if refund successful
//    public func beginRefundProcess(from productId: String, in scene: UIWindowScene) async throws -> Bool{
//        
//        let result = await Transaction.latest(for: productId)
//        
//        switch result{
//        case .verified(let transaction):
//            do {
//                let status = try await transaction.beginRefundRequest(in: scene)
//                switch status{
//                case .success:
//                    PXLog.event(.refundSuccess)
//                    return true
//                case .userCancelled:
//                    PXLog.event(.refundUserCancel)
//                    return false
//                @unknown default:
//                    PXLog.event(.refundFailure)
//                    return false
//                }
//            } catch {
//                PXLog.event(.refundFailure)
//                throw error
//            }
//        case .unverified(_, _):
//            PXLog.event(.refundFailure)
//            return false
//        case .none:
//            PXLog.event(.refundFailure)
//            return false
//        }
//    }
    
    /// Observe transaction
    /// - Returns: A Task object
    private func handTransaction() -> Task<Void, Error> {

            return Task.detached{
                for await verificationResult in Transaction.updates {
                    
                    let checkResult = self.checkTransactionVerificationResult(result: verificationResult)
                    
                    if checkResult.verified {
                        let validatedTransaction = checkResult.transaction
                        await validatedTransaction.finish()
                    } else {
                        
                    }
                }
            }
        }
    
    /// Verified Transaction
    /// - Parameter result:  Transaction for products which we purchased
    /// - Returns: The result of this verification
    private func checkTransactionVerificationResult(result: VerificationResult<Transaction>) -> (transaction: Transaction, verified: Bool) {
            switch result {
            case .unverified(let transaction, _):
                return (transaction: transaction, verified: false)
            case .verified(let transaction):
                return (transaction: transaction, verified: true)
            }
        }

    /// 创建 appAccountToken
    /// - Parameter userID: 用户 ID 字符串
    /// - Returns: UUID 对象，如果转换失败则返回 nil
    private func createAppAccountToken(from userID: String) -> UUID? {
        // 尝试直接将 userID 转换为 UUID
        if let uuid = UUID(uuidString: userID) {
            return uuid
        }

        // 如果 userID 不是标准 UUID 格式，使用哈希生成确定性 UUID
        // 使用 userID 的 hash 值生成 UUID（确保同一用户每次生成相同的 UUID）
        let hash = userID.hash
        let uuidString = String(format: "%08x-0000-0000-0000-000000000000", UInt32(bitPattern: Int32(truncatingIfNeeded: hash)))
        return UUID(uuidString: uuidString)
    }
}

extension PurchaseXManager {
    
    /// Reset keychain
    public func resetKeychainConsumables(){
        guard products != nil else {
            return
        }
        
        let consumableProductIds = products!.filter({ $0.type == .consumable}).map({ $0.id })
        if !PXDataPersistence.resetAllConsumable(productIds: Set(consumableProductIds)) {
            PXLog.event("reset failed")
        }
    }
}
