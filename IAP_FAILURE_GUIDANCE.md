# IAP 支付失败引导功能实现文档

## 功能概述

为了改善用户在 IAP 支付失败时的体验，实现了一套完整的支付失败处理和官网引导机制。当用户遇到各种支付问题时，应用会根据错误类型提供个性化的提示信息，并在适当的情况下引导用户前往官网进行购买。

## 核心设计

### 1. 错误类型增强 (`PurchaseXException`)

扩展了原有的错误类型，新增了以下错误场景：

- `userNotAllowedToMakePurchases`: 设备限制购买
- `paymentMethodNotAvailable`: 支付方式不可用
- `networkError(String)`: 网络连接问题
- `unknownError(String)`: 未知错误

### 2. 用户友好的错误信息

每种错误类型都提供了中文的用户友好提示：

```swift
public func userFriendlyMessage() -> String {
    switch self {
    case .userNotAllowedToMakePurchases:
        return "当前账户不允许进行购买，请检查设备限制设置"
    case .paymentMethodNotAvailable:
        return "支付方式不可用，请检查您的支付设置"
    case .networkError(_):
        return "网络连接出现问题，请检查网络后重试"
    // ...
    }
}
```

### 3. 智能官网引导策略

通过 `shouldShowWebsiteOption()` 方法判断是否显示官网购买选项：

- ✅ **显示官网引导**：支付失败、权限问题、网络问题等
- ❌ **不显示官网引导**：购买进行中、验证失败等技术问题

### 4. 统一的失败处理组件 (`PurchaseFailureAlert`)

创建了可复用的 Alert 组件，支持：
- 根据错误类型自动调整提示内容
- 智能显示"前往官网"或"重试"按钮
- 跨平台支持（iOS/tvOS/macOS）

## 技术实现

### 1. 错误处理流程

```
IAP 购买失败 → 捕获具体错误类型 → 分析错误原因 → 显示个性化提示 → 提供官网引导
```

### 2. PurchaseXManager 增强

改进了 `purchase()` 方法的错误处理：

```swift
} catch {
    // 根据错误类型抛出更具体的异常
    if let storeKitError = error as? StoreKitError {
        switch storeKitError {
        case .notAllowedToMakePayments:
            throw PurchaseXException.userNotAllowedToMakePurchases
        case .paymentNotAllowed:
            throw PurchaseXException.paymentMethodNotAvailable
        case .networkError(_):
            throw PurchaseXException.networkError(storeKitError.localizedDescription)
        default:
            throw PurchaseXException.unknownError(storeKitError.localizedDescription)
        }
    }
}
```

### 3. PurchaseView 集成

在购买页面中集成新的错误处理机制：

```swift
} catch {
    // 检查是否是我们自定义的购买异常
    if let purchaseError = error as? PurchaseXException {
        await MainActor.run {
            purchaseFailureError = purchaseError
            showPurchaseFailureAlert = true
        }
    } else {
        // 其他类型错误使用原有提示
        await MainActor.run {
            presentAlert("购买出错: \(error.localizedDescription)")
        }
    }
}
```

### 4. 官网链接处理

自动构建官网购买页面链接：

```swift
let websiteURL = "\(Defaults[.host])/#/buy"
```

支持跨平台打开：
- iOS/tvOS: 使用 `UIApplication.shared.open()`
- macOS: 使用 `NSWorkspace.shared.open()`

## 用户体验流程

### 场景 1：设备限制购买
1. 用户点击购买 → 2. 系统检测到设备限制 → 3. 显示友好提示："当前账户不允许进行购买，请检查设备限制设置" → 4. 提供"前往官网"选项

### 场景 2：网络连接问题
1. 用户点击购买 → 2. 网络请求失败 → 3. 显示提示："网络连接出现问题，请检查网络后重试" → 4. 提供"前往官网"选项

### 场景 3：购买进行中
1. 用户快速多次点击购买 → 2. 检测到购买进行中 → 3. 显示提示："已有购买正在进行中，请稍后再试" → 4. 只提供"重试"选项（不显示官网引导）

## 文件变更清单

### 修改的文件
1. `SharedPaymentKit/PurchaseX/PurchaseXHelper/PurchaseXException.swift`
   - 新增错误类型
   - 添加用户友好提示方法
   - 添加官网引导判断逻辑

2. `SharedPaymentKit/PurchaseX/PurchaseXHelper/PurchaseXManager.swift`
   - 增强错误处理，提供更详细的错误分类
   - 改进 `purchase()` 方法的异常抛出机制

3. `SharedPaymentKit/Views/PurchaseView.swift`
   - 添加购买失败状态管理
   - 集成新的错误处理 Alert
   - 添加官网跳转方法

### 新增的文件
1. `SharedPaymentKit/Views/PurchaseFailureAlert.swift`
   - 购买失败专用 Alert 组件
   - 跨平台官网跳转支持
   - 错误信息模型定义

2. `SharedPaymentKit/Tests/PurchaseFailureHandlingTests.swift`
   - 功能测试用例
   - 模拟失败场景的工具方法

## 测试验证

通过 `PurchaseFailureHandlingTests` 可以验证：
- ✅ 错误消息的正确性
- ✅ 官网引导逻辑的准确性
- ✅ 不同错误场景的处理

运行测试：
```swift
PurchaseFailureHandlingTests.runAllTests()
```

## 配置要求

确保在 `Defaults[.host]` 中配置了正确的官网 URL，引导链接会自动构建为：
```
{官网域名}/#/buy
```

## 兼容性

- ✅ iOS 15.0+
- ✅ tvOS 15.0+
- ✅ macOS 12.0+
- ✅ 向后兼容现有购买流程

## 总结

这套实现为用户提供了更好的购买失败体验：

1. **用户友好**: 提供中文化的、易于理解的错误提示
2. **智能引导**: 根据错误类型智能决定是否显示官网购买选项
3. **无缝衔接**: 在原有购买流程基础上增强，不影响正常购买
4. **跨平台**: 支持 iOS、tvOS、macOS 全平台
5. **可扩展**: 错误类型和处理逻辑易于扩展

通过这套机制，当用户遇到 IAP 购买问题时，可以获得清晰的指引并便捷地转向官网完成购买，显著改善了用户体验和转化率。