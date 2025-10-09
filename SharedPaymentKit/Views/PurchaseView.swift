//
//  PurchaseView.swift
//  SFI
//
//  简洁的 IAP 购买视图：预下单 + 购买 + 上报 + 恢复
//

import SwiftUI
import StoreKit
import ExytePopupView
#if canImport(UIKit)
import UIKit
#endif

private struct ProductRow: View {
    let product: Product
    let periodName: String
    let onPurchase: (Product) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName).font(.body)
                Text(periodName).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(product.displayPrice).font(.subheadline).foregroundColor(.secondary)
            Button("购买") { onPurchase(product) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 6)
    }
}

struct PurchaseView: View {
    @StateObject private var purchaseManager = PurchaseXManager()
    @EnvironmentObject var userManager: UserManager
    @State private var isLoadingProducts = false
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var plans: [Plan] = []

    // App Store 实际上架的商品 ID（客户端展示与购买使用）
    let productIDs = [
//                        "com.gy.iflash.7","com.gy.iflash.30","com.gy.iflash.365",
                      "com.gy.iflash.bcup.month","com.gy.iflash.bcup.quart","com.gy.iflash.bcup.year",
                      "com.gy.iflash.ccup.month","com.gy.iflash.ccup.quart","com.gy.iflash.ccup.year",
                      "com.gy.iflash.dcup.month","com.gy.iflash.dcup.quart","com.gy.iflash.dcup.year",
                      "com.gy.iflash.zcup.year"
//                      "com.gy.iflash.zcup.month","com.gy.iflash.zcup.quart","com.gy.iflash.zcup.year"
                    ]

    // 注意：不在 App 端做商品映射，直接将 App Store 的 product.id 传给后端，
    // 后端通过配置（config/iap.php）完成 product.id → plan_id/months 的映射。

    var body: some View {
        Group {
            if isLoadingProducts {
                VStack { Spacer(); ProgressView("加载中..."); Spacer() }
            } else {
                List { groupedProductSections }
                .listStyle(.insetGrouped)
                .disabled(isPurchasing)
            }
        }
        .navigationTitle("选择套餐")
        .onAppear {
            // 购买成功回调仅记录日志；真正上报在购买流程里（可带 tradeNo 与 appToken）
            purchaseManager.onPurchaseSuccess = { tx in
                print("购买成功：\(tx.productID)")
            }
            Task { await precheckAndLoad() }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("提示"), message: Text(errorMessage ?? ""), dismissButton: .default(Text("确定")))
        }
        .popup(isPresented: $isPurchasing) {
            purchasingToast
        } customize: {
            $0.type(.toast)
              .position(.center)
              .animation(.easeInOut)
              .closeOnTap(false)
              .closeOnTapOutside(false)
        }
    }

    // MARK: - 分组展示（中杯/大杯/超大杯/无限 × 月/季/年）
    private var groupedProductSections: some View {
        Group {
            if let products = purchaseManager.products, !products.isEmpty {
                let dict = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
                let groups: [(key: String, name: String, planID: Int64, periods: [(code: String, label: String)])] = [
                    ("bcup", "常规 中杯", 7, [("month","月付"), ("quart","季付"), ("year","年付")]),
                    ("ccup", "常规 大杯", 2, [("month","月付"), ("quart","季付"), ("year","年付")]),
                    ("dcup", "常规 超大杯", 8, [("month","月付"), ("quart","季付"), ("year","年付")]),
                    ("zcup", "无限流量", 9, [("year","年付")]),
                ]

                ForEach(groups, id: \.key) { g in
                    Section(header: sectionHeader(for: g)) {
                        ForEach(g.periods, id: \.code) { p in
                            let pid = "com.gy.iflash.\(g.key).\(p.code)"
                            if let prod = dict[pid] {
                                ProductRow(product: prod, periodName: p.label) { product in
                                    Task { await purchaseProduct(product) }
                                }
                            }
                        }
                    }
                }
            } else {
                Section {
                    Text("暂无可用商品").foregroundColor(.gray)
                }
            }
            Section(footer: Text("若已在其它设备购买，可在此恢复购买")) {
                Button("恢复购买") { Task { await restorePurchases() } }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(for group: (key: String, name: String, planID: Int64, periods: [(code: String, label: String)])) -> some View {
        if let plan = plans.first(where: { $0.id == group.planID }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.name).font(.headline)
                HStack(spacing: 12) {
                    Text("每月 \(plan.transfer_enable)G")
                    if let speed = plan.speed_limit { Text("限速 \(speed)Mbps") }
                }.font(.caption).foregroundColor(.secondary)
                if let rich = htmlToAttributedString(plan.content) {
                    Text(rich)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            Text(group.name)
        }
    }

    // 将后端返回的 HTML 文本渲染成富文本展示
    private func htmlToAttributedString(_ html: String) -> AttributedString? {
        #if canImport(UIKit)
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return AttributedString(ns)
        }
        return nil
        #else
        return nil
        #endif
    }

    private var purchasingToast: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在处理订单...")
                .font(.caption)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(16)
    }

    // 加载产品列表
    private func loadProducts() {
        Task { await loadProductsAsync(showLoading: true) }
    }

    // 购买流程：预下单 → 购买 → 上报
    private func purchaseProduct(_ product: Product) async {
        guard userManager.isLoggedIn else {
            await MainActor.run {
                errorMessage = "请先登录"
                showAlert = true
            }
            return
        }
        await MainActor.run { isPurchasing = true }

        guard let appToken = userManager.userInfo?.app_account_token, !appToken.isEmpty else {
            // 尝试预刷新一次
            let ok = await ensureAppToken()
            guard ok, let refreshed = userManager.userInfo?.app_account_token, !refreshed.isEmpty else {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = "账户标识缺失，请重新登录后再试"
                    showAlert = true
                }
                return
            }
            await performPurchase(product: product, appToken: refreshed)
            return
        }

        await performPurchase(product: product, appToken: appToken)
    }

    // 执行实际预下单 + 购买 + 上报
    private func performPurchase(product: Product, appToken: String) async {
        // 1) 预下单，获取 trade_no（失败不阻塞购买）
        var tradeNo: String? = nil
        let sem = DispatchSemaphore(value: 0)
        NewNetWorkRequest(
            AQAPIService.prepareIAPOrder(productID: product.id, appAccountToken: appToken),
            modelType: PrepareIAPOrderResponse.self
        ) { model, _ in tradeNo = model?.trade_no; sem.signal() }
        _ = sem.wait(timeout: .now() + 8) // 最多等待 8 秒，避免长时间卡死

        // 2) 发起购买（注入 appAccountToken）
        do {
            let result = try await purchaseManager.purchase(product: product, userID: appToken)
            await MainActor.run {
                switch result.purchaseState {
                case .complete:
                    if let tx = result.transaction {
                        // 不再等待上报完成再关闭 loading，避免网络失败时卡住
                        isPurchasing = false
                        IAPOrderManager.reportOrder(transaction: tx, tradeNo: tradeNo, appAccountToken: appToken) { success, err in
                            DispatchQueue.main.async {
                                if success { userManager.reload(); errorMessage = "购买成功！" }
                                else { errorMessage = "购买成功，但订单同步失败: \(err ?? "未知错误")" }
                                showAlert = true
                            }
                        }
                    } else {
                        isPurchasing = false
                        errorMessage = "购买完成，但未获取到交易信息"
                        showAlert = true
                    }
                case .cancelled:
                    isPurchasing = false
                    errorMessage = "购买已取消"
                    showAlert = true
                case .pending:
                    isPurchasing = false
                    errorMessage = "购买待处理，请稍后查看"
                    showAlert = true
                case .failed:
                    isPurchasing = false
                    errorMessage = "购买失败"
                    showAlert = true
                default:
                    isPurchasing = false
                    errorMessage = "未知错误"
                    showAlert = true
                }
            }
        } catch {
            await MainActor.run {
                isPurchasing = false
                errorMessage = "购买失败：\(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    // 预检查 app_account_token 并加载商品
    private func precheckAndLoad() async {
        _ = await ensureAppToken()
        await loadPlans()
        await loadProductsAsync(showLoading: true)
    }

    private func loadProductsAsync(showLoading: Bool = false) async {
        if showLoading {
            await MainActor.run { isLoadingProducts = true }
        }
        _ = await purchaseManager.requestProductsFromAppstore(productIds: productIDs)
        if showLoading {
            await MainActor.run { isLoadingProducts = false }
        }
    }

    // 拉取后端套餐计划，用于展示组头信息
    private func loadPlans() async {
        let sem = DispatchSemaphore(value: 0)
        NewNetWorkRequest(
            AQAPIService.getPlans,
            modelType: PlanListResponse.self
        ) { model, _ in
            if let list = model?.data {
                DispatchQueue.main.async { self.plans = list }
            }
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 8)
    }

    // 确保用户信息中有 app_account_token；必要时触发刷新并等待
    private func ensureAppToken() async -> Bool {
        if let t = userManager.userInfo?.app_account_token, !t.isEmpty { return true }
        // 触发刷新
        userManager.reload()
        // 等待最多 2 秒，轮询几次
        for _ in 0..<4 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if let t = userManager.userInfo?.app_account_token, !t.isEmpty { return true }
        }
        return false
    }

    // 恢复购买：采集 StoreKit2 交易快照并上报后端
    private func restorePurchases() async {
        guard userManager.isLoggedIn else {
            DispatchQueue.main.async { errorMessage = "请先登录"; showAlert = true }
            return
        }
        guard let appToken = userManager.userInfo?.app_account_token, !appToken.isEmpty else {
            DispatchQueue.main.async { errorMessage = "账户标识缺失，请重新登录后再试"; showAlert = true }
            return
        }
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
// 网络响应模型
private struct PlanListResponse: Codable { let data: [Plan] }

#Preview {
    PurchaseView().environmentObject(UserManager())
}
