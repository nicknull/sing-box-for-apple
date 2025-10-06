//
//  PurchaseView.swift
//  SFI
//
//  简洁的 IAP 购买视图：预下单 + 购买 + 上报 + 恢复
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var purchaseManager = PurchaseXManager()
    @EnvironmentObject var userManager: UserManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAlert = false

    // 示例产品 ID（请根据实际配置替换）
    let productIDs = ["com.gy.iflash.7","com.gy.iflash.30","com.gy.iflash.365"]

    var body: some View {
        VStack(spacing: 16) {
            Text("选择套餐").font(.title).bold()

            if isLoading {
                ProgressView("加载中...")
            } else if let products = purchaseManager.products {
                ForEach(products, id: \.id) { product in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(product.displayName).font(.headline)
                            Text(product.description).font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                        Button("购买") { Task { await purchaseProduct(product) } }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            } else {
                Text("暂无可用商品").foregroundColor(.gray)
            }

            Button("恢复购买") { Task { await restorePurchases() } }
        }
        .padding()
        .onAppear {
            // 购买成功回调仅记录日志；真正上报在购买流程里（可带 tradeNo 与 appToken）
            purchaseManager.onPurchaseSuccess = { tx in
                print("购买成功：\(tx.productID)")
            }
            loadProducts()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("确定")))
        }
    }

    // 加载产品列表
    private func loadProducts() {
        isLoading = true
        Task {
            _ = await purchaseManager.requestProductsFromAppstore(productIds: productIDs)
            isLoading = false
        }
    }

    // 购买流程：预下单 → 购买 → 上报
    private func purchaseProduct(_ product: Product) async {
        guard userManager.isLoggedIn else {
            DispatchQueue.main.async { errorMessage = "请先登录"; showAlert = true }
            return
        }
        isLoading = true
        do {
            let appToken = userManager.userInfo?.app_account_token ?? userManager.auth_data
            // 1) 预下单，获取 trade_no
            var tradeNo: String? = nil
            let sem = DispatchSemaphore(value: 0)
            NewNetWorkRequest(
                AQAPIService.prepareIAPOrder(productID: product.id, appAccountToken: appToken),
                modelType: PrepareIAPOrderResponse.self
            ) { model, _ in tradeNo = model?.trade_no; sem.signal() }
            _ = sem.wait(timeout: .now() + 10)

            // 2) 发起购买（注入 appAccountToken）
            let userID = userManager.userInfo?.app_account_token ?? userManager.auth_data
            let (transaction, state) = try await purchaseManager.purchase(product: product, userID: userID)

            DispatchQueue.main.async {
                isLoading = false
                switch state {
                case .complete:
                    if let tx = transaction {
                        IAPOrderManager.reportOrder(transaction: tx, tradeNo: tradeNo, appAccountToken: appToken) { success, err in
                            DispatchQueue.main.async {
                                if success { userManager.reload(); errorMessage = "购买成功！" }
                                else { errorMessage = "购买成功，但订单同步失败: \(err ?? "未知错误")" }
                                showAlert = true
                            }
                        }
                    } else {
                        errorMessage = "购买完成，但未获取到交易信息"; showAlert = true
                    }
                case .cancelled: errorMessage = "购买已取消"; showAlert = true
                case .pending: errorMessage = "购买待处理，请稍后查看"; showAlert = true
                case .failed: errorMessage = "购买失败"; showAlert = true
                default: errorMessage = "未知错误"; showAlert = true
                }
            }
        } catch {
            DispatchQueue.main.async { isLoading = false; errorMessage = "购买出错: \(error.localizedDescription)"; showAlert = true }
        }
    }

    // 恢复购买：采集 StoreKit2 交易快照并上报后端
    private func restorePurchases() async {
        guard userManager.isLoggedIn else {
            DispatchQueue.main.async { errorMessage = "请先登录"; showAlert = true }
            return
        }
        let appToken = userManager.userInfo?.app_account_token ?? userManager.auth_data
        let snapshot = await purchaseManager.transactionsSnapshot()
        IAPOrderManager.restorePurchases(appAccountToken: appToken, transactions: snapshot) { success, error in
            DispatchQueue.main.async {
                if success { userManager.reload(); errorMessage = "恢复完成" }
                else { errorMessage = error ?? "恢复失败" }
                showAlert = true
            }
        }
    }
}

#Preview {
    PurchaseView().environmentObject(UserManager())
}
