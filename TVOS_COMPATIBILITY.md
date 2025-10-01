# tvOS 平台兼容性分析与适配方案

## 📋 概述

本文档分析了 iOS 端新增功能（OAuth 登录、IAP 订单、FCM 推送）在 tvOS 平台的兼容性，并提供适配方案。

## 🎯 tvOS 平台特性

### 1. tvOS 限制

- ❌ **不支持 StoreKit 2**：tvOS 不支持 StoreKit 2 框架
- ❌ **不支持 Sign in with Apple UI**：没有 `ASAuthorizationAppleIDButton`
- ⚠️ **有限的 Firebase 支持**：Firebase Messaging 在 tvOS 上支持有限
- ⚠️ **输入方式受限**：主要使用遥控器，无键盘（除非连接外设）
- ✅ **支持 OAuth 2.0**：可以通过网页认证实现
- ✅ **支持推送通知**：tvOS 10+ 支持用户通知

### 2. 当前项目 tvOS 支持

项目已有 **TVExtension** 目标，并在多处代码中使用了平台判断：

```swift
#if os(tvOS)
    // tvOS 特定代码
#elseif os(iOS)
    // iOS 特定代码
#endif
```

## 🔍 功能兼容性分析

### 1. ❌ IAP 订单功能（不兼容 tvOS）

**问题：**
- 使用了 StoreKit 2 (`import StoreKit`)
- tvOS 只支持 StoreKit 1（旧版 API）

**影响文件：**
- `SFI/PurchaseX/PurchaseXManager.swift`
- `SFI/PurchaseX/IAPOrderManager.swift`
- `SFI/PurchaseView.swift`

**适配方案：**

#### 方案 1：使用 StoreKit 1 API（推荐）
为 tvOS 创建独立的 IAP 管理器：

```swift
// PurchaseXManagerTV.swift (新建)
#if os(tvOS)
import StoreKit  // StoreKit 1

class PurchaseXManagerTV: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    static let shared = PurchaseXManagerTV()

    // 使用 StoreKit 1 API 实现购买逻辑
    func purchase(productID: String, userID: String?) {
        // StoreKit 1 购买流程
    }
}
#endif
```

#### 方案 2：禁用 IAP 功能
在 tvOS 上隐藏购买入口：

```swift
#if !os(tvOS)
// 显示购买按钮
Button("购买套餐") { ... }
#endif
```

---

### 2. ⚠️ OAuth 登录功能（部分兼容）

#### Apple 登录（需要适配）

**问题：**
- tvOS 不支持 `ASAuthorizationAppleIDButton` UI 组件
- 需要使用 `ASAuthorizationController` 的替代方案

**适配方案：**

```swift
// AppleSignInManager.swift
#if os(tvOS)
import AuthenticationServices

// tvOS 使用编程方式触发 Apple 登录
func signInWithApple() {
    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.fullName, .email]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.performRequests()
}
#endif
```

**UI 适配：**
```swift
// LoginView.swift
#if os(tvOS)
Button("使用 Apple 账号登录") {
    oauthManager.signInWithApple()
}
.buttonStyle(.card)  // tvOS 专用样式
#else
SignInWithAppleButton(.signIn) { request in
    // iOS 实现
}
#endif
```

#### Google/GitHub 登录（完全兼容）

**状态：** ✅ 可直接使用

- 使用 `ASWebAuthenticationSession` 进行网页认证
- tvOS 支持 Safari View Controller
- 无需修改

---

### 3. ⚠️ FCM 推送通知（需要适配）

**问题：**
- Firebase Messaging 在 tvOS 上支持有限
- tvOS 不支持 `UIApplication.registerForRemoteNotifications()` 的某些功能

**当前实现问题：**
```swift
// SFI/ApplicationDelegate.swift
import FirebaseMessaging  // ⚠️ tvOS 支持有限

extension ApplicationDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Firebase Messaging 在 tvOS 上可能无法正常工作
    }
}
```

**适配方案：**

#### 方案 1：使用原生 APNS（推荐）

```swift
// ApplicationDelegate.swift
#if os(tvOS)
import UserNotifications

func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    // tvOS 使用原生推送
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        if granted {
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
    return true
}

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // 直接上传 APNS Token 到后端
    uploadAPNSToken(tokenString)
}
#else
// iOS 使用 Firebase
FirebaseApp.configure()
Messaging.messaging().delegate = self
#endif
```

#### 方案 2：禁用推送功能

```swift
#if os(tvOS)
// tvOS 不支持推送，使用轮询方式检查工单更新
Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    checkTicketUpdates()
}
#endif
```

---

### 4. ✅ 工单图片上传（完全兼容）

**状态：** ✅ 可直接使用

- 图片选择器需要 tvOS 适配
- 使用 `UIImagePickerController` 或 `PHPickerViewController`

**适配示例：**
```swift
#if os(tvOS)
// tvOS 使用系统相册选择器
import PhotosUI

struct TVImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    // ...
}
#endif
```

---

## 🛠️ 适配实施方案

### 优先级 1：必须适配

#### 1. FCM Token 管理（FCMTokenManager.swift）

```swift
// FCMTokenManager.swift
#if os(tvOS)
import UserNotifications

class APNSTokenManager {
    static let shared = APNSTokenManager()

    func uploadToken(_ apnsToken: String) {
        NewNetWorkRequest(
            AQAPIService.registerDeviceToken(token: apnsToken, platform: "tvos"),
            modelType: SimpleResponse.self
        ) { response, error in
            // 处理响应
        }
    }
}
#else
// iOS 使用 FCM
class FCMTokenManager { ... }
#endif
```

#### 2. Apple 登录适配（AppleSignInManager.swift）

```swift
#if os(tvOS)
extension AppleSignInManager {
    func signInForTV() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self

        // tvOS 需要在当前 window 上展示
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            controller.presentationContextProvider = window.rootViewController as? ASAuthorizationControllerPresentationContextProviding
        }

        controller.performRequests()
    }
}
#endif
```

### 优先级 2：可选适配

#### 1. IAP 功能（使用 StoreKit 1）

创建 `PurchaseManagerTV.swift`：

```swift
#if os(tvOS)
import StoreKit

class PurchaseManagerTV: NSObject {
    static let shared = PurchaseManagerTV()

    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }

    func purchase(productID: String, userID: String?) {
        // StoreKit 1 实现
        let payment = SKPayment(product: product)

        // tvOS 不支持 appAccountToken，使用 applicationUsername
        if let userID = userID {
            payment.applicationUsername = userID
        }

        SKPaymentQueue.default().add(payment)
    }
}

extension PurchaseManagerTV: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // 处理交易状态
    }
}
#endif
```

### 优先级 3：UI 适配

#### 1. LoginView 适配

```swift
// LoginView.swift
struct LoginView: View {
    var body: some View {
        #if os(tvOS)
        TVLoginContent()
        #else
        iOSLoginContent()
        #endif
    }
}

#if os(tvOS)
struct TVLoginContent: View {
    var body: some View {
        VStack(spacing: 40) {
            // tvOS 使用更大的字体和间距
            Text("登录")
                .font(.system(size: 60, weight: .bold))

            // Apple 登录按钮（tvOS 样式）
            Button(action: { oauthManager.signInWithApple() }) {
                HStack {
                    Image(systemName: "applelogo")
                        .font(.system(size: 30))
                    Text("使用 Apple 登录")
                        .font(.system(size: 28))
                }
            }
            .buttonStyle(.card)
            .frame(width: 600, height: 120)
        }
    }
}
#endif
```

---

## 📦 后端 API 适配

### 1. 设备 Token 注册

**扩展接口支持平台参数：**

```php
// DeviceController.php
public function registerFcmToken(Request $request)
{
    $validator = Validator::make($request->all(), [
        'fcm_token' => 'sometimes|string',  // iOS
        'apns_token' => 'sometimes|string', // tvOS
        'platform' => 'required|in:ios,tvos,android'
    ]);

    $user = $request->user;

    if ($request->input('platform') === 'tvos') {
        // tvOS 使用 APNS Token
        $user->apns_token = $request->input('apns_token');
    } else {
        // iOS 使用 FCM Token
        $user->fcm_token = $request->input('fcm_token');
    }

    $user->save();
}
```

### 2. 数据库扩展

```php
// 新增迁移
Schema::table('v2_user', function (Blueprint $table) {
    $table->string('apns_token', 255)->nullable()->after('fcm_token');
    $table->string('device_platform', 20)->nullable()->after('apns_token'); // ios, tvos, android
});
```

---

## 📝 总结与建议

### ✅ 完全兼容（无需修改）
- Google OAuth 登录
- GitHub OAuth 登录
- 工单文字功能
- 账号绑定/解绑

### ⚠️ 需要适配
- **Apple 登录**：UI 组件需要 tvOS 适配
- **推送通知**：使用原生 APNS 代替 Firebase
- **图片上传**：使用 tvOS 兼容的图片选择器

### ❌ 不推荐在 tvOS 使用
- **StoreKit 2 IAP**：tvOS 不支持，建议：
  - 方案 1：使用 StoreKit 1 重新实现
  - 方案 2：在 tvOS 上隐藏购买功能，引导用户在 iOS 端购买

### 🎯 推荐实施顺序

1. **阶段 1（必须）：基础适配**
   - ✅ OAuth 登录 tvOS 适配
   - ✅ 推送通知 APNS 适配
   - ✅ 后端 API 扩展支持 tvOS

2. **阶段 2（可选）：功能增强**
   - 工单图片上传 tvOS 适配
   - StoreKit 1 IAP 实现

3. **阶段 3（优化）：用户体验**
   - tvOS 专用 UI 优化
   - 遥控器交互优化
   - Focus Engine 适配

---

## 🔧 快速开始

### 1. 编译检查

```bash
# 检查 tvOS 编译
xcodebuild -workspace sing-box.xcworkspace \
  -scheme SFT \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K' \
  build
```

### 2. 创建 tvOS 专用文件

建议创建以下文件：
- `SFT/TV/` - tvOS 专用视图和管理器
- `APNSTokenManager.swift` - APNS Token 管理
- `PurchaseManagerTV.swift` - tvOS IAP 管理器（可选）

### 3. 修改现有文件

在以下文件中添加 `#if os(tvOS)` 判断：
- `FCMTokenManager.swift`
- `AppleSignInManager.swift`
- `LoginView.swift`
- `UserManager.swift`

---

创建时间：2025-10-01
分支：feature/oauth-login
tvOS 最低支持版本：tvOS 15.0+
