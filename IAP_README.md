# IAP 用户订单绑定功能

## 📋 功能概述

本功能实现了应用内购买（IAP）与用户账号的绑定，确保后端能够识别是哪个用户完成了购买，从而正确开通服务。

## 🔑 核心技术

采用 **StoreKit 2 的 `appAccountToken`** 机制（Apple 官方推荐方案）：

1. **前端**：购买时将用户 ID 作为 `appAccountToken` 传递给 Apple
2. **Apple**：交易信息中包含此 token，可通过 Server-to-Server Notification 发送给后端
3. **后端**：从 Apple 服务器通知中解析 `appAccountToken`，识别用户并绑定订单

## 📂 已修改的文件

### 1. `PurchaseXManager.swift`
- ✅ 添加 `userID` 参数支持
- ✅ 实现 `appAccountToken` 生成逻辑
- ✅ 添加 `onPurchaseSuccess` 回调

```swift
// 使用示例
let (transaction, state) = try await purchaseManager.purchase(
    product: product,
    userID: "user_123"  // 传入用户 ID
)
```

### 2. `AQAPIService.swift`
- ✅ 添加 `reportIAPOrder` API 接口
- ✅ 路径：`/user/order/iap`
- ✅ 参数：`transaction_id`, `original_transaction_id`, `product_id`

### 3. `IAPOrderManager.swift`（新建）
- ✅ 封装订单上报逻辑
- ✅ 处理成功/失败回调

### 4. `PurchaseView.swift`（新建）
- ✅ 完整的购买流程示例
- ✅ 用户登录检查
- ✅ 订单自动上报
- ✅ 错误处理

## 🚀 使用方法

### 步骤 1：初始化购买管理器

```swift
@StateObject private var purchaseManager = PurchaseXManager()
@EnvironmentObject var userManager: UserManager

// 设置购买成功回调
purchaseManager.onPurchaseSuccess = { transaction in
    // 上报订单到后端
    IAPOrderManager.reportOrder(transaction: transaction) { success, error in
        if success {
            userManager.reload()  // 刷新用户信息
        }
    }
}
```

### 步骤 2：加载产品

```swift
let productIDs = ["com.yourapp.monthly", "com.yourapp.yearly"]
await purchaseManager.requestProductsFromAppstore(productIds: productIDs)
```

### 步骤 3：发起购买

```swift
let userID = userManager.userInfo?.id?.description ?? userManager.auth_data

let (transaction, state) = try await purchaseManager.purchase(
    product: product,
    userID: userID  // 关键：传入用户 ID
)

// state 可能的值：.complete, .cancelled, .pending, .failed
```

## 🔧 后端需要做的事情

### 1. 配置 Apple Server-to-Server Notification

在 App Store Connect 中配置回调 URL：
```
https://your-backend.com/api/v1/apple/webhook
```

### 2. 接收并验证通知

```json
{
  "signedPayload": "eyJhbGciOiJFUzI1NiIsIng1YyI6W..."
}
```

解析 JWT 后可获取：
- `transactionId`: 交易 ID
- `originalTransactionId`: 原始交易 ID（用于识别同一用户的续订）
- `appAccountToken`: 用户 ID（UUID 格式）
- `productId`: 产品 ID

### 3. 处理前端主动上报的订单

接口：`POST /api/v1/user/order/iap`

请求参数：
```json
{
  "transaction_id": "2000000123456789",
  "original_transaction_id": "2000000123456789",
  "product_id": "com.yourapp.monthly"
}
```

响应：
```json
{
  "code": 200,
  "data": {
    "order_id": "ORD_123456",
    "message": "订单创建成功"
  }
}
```

### 4. 验证收据（可选，增强安全性）

调用 Apple 服务器验证 API：
```
POST https://buy.itunes.apple.com/verifyReceipt
```

## 🎯 双重保障机制

1. **appAccountToken**（推荐，自动）
   - Apple 自动发送 Server-to-Server Notification
   - 后端从通知中解析 `appAccountToken` 绑定用户
   - 即使前端上报失败，后端也能处理

2. **主动上报**（兜底）
   - 前端购买成功后主动调用 API
   - 防止通知延迟或丢失
   - 用户立即看到服务开通

## 📊 数据流程图

```
用户点击购买
    ↓
购买时传入 userID（appAccountToken）
    ↓
Apple 处理购买
    ↓
    ├─→ [自动] Apple 发送 Server Notification → 后端解析 appAccountToken → 绑定订单
    └─→ [主动] 前端调用 reportIAPOrder API → 后端创建订单
    ↓
后端开通服务
    ↓
前端刷新用户信息
```

## ⚠️ 注意事项

1. **userID 格式**
   - 支持 UUID 格式字符串
   - 其他格式会自动转换为确定性 UUID（使用 hash）
   - 同一用户每次生成的 UUID 相同

2. **安全性**
   - 后端必须验证 Apple 服务器通知的签名
   - 不要仅依赖前端上报，要同时处理 Server Notification
   - 防止恶意请求伪造订单

3. **测试环境**
   - 沙盒环境验证收据 URL：`https://sandbox.itunes.apple.com/verifyReceipt`
   - 生产环境 URL：`https://buy.itunes.apple.com/verifyReceipt`

4. **错误处理**
   - 购买失败时要有明确提示
   - 订单上报失败时记录日志，便于人工处理
   - 用户换设备恢复购买时也要正确识别用户

## 🧪 测试清单

- [ ] 正常购买流程
- [ ] 购买取消
- [ ] 网络异常时的购买
- [ ] 订单上报失败的处理
- [ ] 恢复购买（同一账号不同设备）
- [ ] 订阅续费
- [ ] 订阅取消
- [ ] 退款处理

## 📚 参考资料

- [Apple StoreKit 2 文档](https://developer.apple.com/documentation/storekit)
- [App Store Server Notifications V2](https://developer.apple.com/documentation/appstoreservernotifications)
- [验证收据](https://developer.apple.com/documentation/appstorereceipts/verifyreceipt)

## 🔍 调试建议

1. 在 `IAPOrderManager.reportOrder` 中添加日志
2. 使用 Charles/Proxyman 抓包查看 API 请求
3. 在 App Store Connect 中查看沙盒测试用户
4. 检查后端是否收到 Apple Server Notification

---

创建时间：2025-10-01
分支：feature/iap-user-binding
