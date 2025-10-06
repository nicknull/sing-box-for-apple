//
//  PurchaseView.swift
//  SFI
//
//  示例：如何使用支付功能并绑定用户订单
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var purchaseManager = PurchaseXManager()
    @EnvironmentObject var userManager: UserManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAlert = false

    // 产品 ID 列表（需要在 App Store Connect 中配置）
    let productIDs = [
        "com.yourapp.monthly.subscription",
        "com.yourapp.yearly.subscription",
        "com.yourapp.lifetime.purchase"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("选择套餐")
                .font(.title)
                .bold()

            if isLoading {
                ProgressView("加载中...")
            } else if let products = purchaseManager.products {
                ForEach(products, id: \.id) { product in
                    ProductCard(product: product) {
                        // 购买按钮点击
                        Task {
                            await purchaseProduct(product)
                        }
                    }
                }
            } else {
                Text("暂无可用商品")
                    .foregroundColor(.gray)
            }

            // 恢复购买按钮
            Button {
                Task {
                    await restorePurchases()
                }
            } label: {
                Text("恢复购买")
                    .bold()
            }
        }
        .padding()
        .onAppear {
            setupPurchaseManager()
            loadProducts()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text(errorMessage ?? ""),
                dismissButton: .default(Text("确定"))
            )
        }
    }

    // MARK: - 设置购买管理器
    private func setupPurchaseManager() {
        // 设置购买成功回调
        purchaseManager.onPurchaseSuccess = { transaction in
            print("🎉 购买成功：\(transaction.productID)")
        }
    }
        }
    }

    // MARK: - 加载产品
    private func loadProducts() {
        isLoading = true
        Task {
            await purchaseManager.requestProductsFromAppstore(productIds: productIDs)
            isLoading = false
        }
    }

    // MARK: - 购买产品
    private func purchaseProduct(_ product: Product) async {
        guard userManager.isLoggedIn else {
            DispatchQueue.main.async {
                errorMessage = "请先登录"
                showAlert = true
            }
            return
        }

        isLoading = true

        do {
            // 1) 预下单，获取 trade_no
            let appToken = userManager.userInfo?.app_account_token ?? ""
            var tradeNo: String? = nil
            let semaphore = DispatchSemaphore(value: 0)
            NewNetWorkRequest(
                AQAPIService.prepareIAPOrder(productID: product.id, appAccountToken: appToken),
                modelType: PrepareIAPOrderResponse.self
            ) { model, resp in
                tradeNo = model?.trade_no
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 10)

            // 使用稳定的 app_account_token 作为 appAccountToken 来源
            let userID = userManager.userInfo?.app_account_token ?? userManager.auth_data

            // 2) 发起购买（将 userID 作为 appAccountToken 注入）
            let (transaction, state) = try await purchaseManager.purchase(
                product: product,
                userID: userID
            )

            DispatchQueue.main.async {
                isLoading = false

                switch state {
                case .complete:
                    print("✅ 购买完成")
                    // 3) 上报订单，携带 trade_no 与 app_account_token（解包可选交易）
                    if let tx = transaction {
                        IAPOrderManager.reportOrder(transaction: tx, tradeNo: tradeNo, appAccountToken: appToken) { success, error in
                            DispatchQueue.main.async {
                                if success {
                                    userManager.reload()
                                    errorMessage = "购买成功！"
                                } else {
                                    errorMessage = "购买成功，但订单同步失败: \ (error ?? \"未知错误\")"
                                }
                                showAlert = true
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            errorMessage = "购买完成，但未获取到交易信息"
                            showAlert = true
                        }
                    }
                }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

#Preview {
    PurchaseView()
        .environmentObject(UserManager())
}
