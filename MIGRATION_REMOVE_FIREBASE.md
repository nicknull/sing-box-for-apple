# iOS 端 Firebase 迁移到 APNS 指南

## 📱 概述

本指南将帮助你将 sing-box-for-apple iOS 项目从 Firebase Cloud Messaging (FCM) 迁移到原生 Apple Push Notification Service (APNS)。

---

## 🎯 迁移目标

- **移除** Firebase 依赖（FirebaseCore, FirebaseMessaging）
- **使用** 原生 APNS Device Token
- **简化** 推送通知配置
- **提升** 推送性能和可靠性

---

## 📦 需要修改的文件

### 1. **Podfile** - 移除 Firebase 依赖

**当前代码**（包含 Firebase）:
```ruby
pod 'FirebaseCore'
pod 'FirebaseMessaging'
```

**修改后**（移除 Firebase）:
```ruby
# Firebase 已移除，使用原生 APNS
```

**操作步骤**:
```bash
cd /Users/xiaokangchen/Documents/VNN/sing-box-for-apple

# 编辑 Podfile，移除 Firebase 相关的 pod
vim Podfile

# 重新安装依赖
pod deintegrate
pod install
```

---

### 2. **SharedNotificationKit/Services/DeviceTokenManager.swift** - 核心修改

**当前代码** (使用 Firebase):
```swift
import FirebaseMessaging

class DeviceTokenManager {
    func uploadTokenIfNeeded(_ fcmToken: String) {
        // 上传 FCM Token 到后端
    }
}
```

**修改后** (使用原生 APNS):
```swift
import Foundation
import UserNotifications

class DeviceTokenManager: NSObject {
    static let shared = DeviceTokenManager()

    private var deviceToken: String?

    /// 注册推送通知权限
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// 处理获取到的 Device Token
    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        print("APNS Device Token: \(token)")

        // 上传到后端
        uploadDeviceToken(token)
    }

    /// 处理注册失败
    func handleRegistrationError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    /// 上传 Device Token 到后端
    private func uploadDeviceToken(_ token: String) {
        guard let apiURL = URL(string: "\(APIConfig.baseURL)/api/v1/user/device/register") else {
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(getAuthToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let platform: String
        #if os(iOS)
        platform = "ios"
        #elseif os(tvOS)
        platform = "tvos"
        #else
        platform = "ios"
        #endif

        let body: [String: Any] = [
            "device_token": token,
            "platform": platform
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to upload device token: \(error)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Device token uploaded successfully")
            } else {
                print("Failed to upload device token, status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }
        }.resume()
    }

    /// 获取当前认证 Token（需要根据你的实现调整）
    private func getAuthToken() -> String {
        // 从 UserDefaults 或 Keychain 获取 auth_data
        return UserDefaults.standard.string(forKey: "auth_data") ?? ""
    }
}
```

---

### 3. **SharedUserKit/Services/UserManager.swift** - 移除 Firebase 引用

**修改前**:
```swift
import FirebaseCore
import FirebaseMessaging

class UserManager {
    func initializeFirebase() {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
    }
}
```

**修改后**:
```swift
// 移除 Firebase 导入
// import FirebaseCore
// import FirebaseMessaging

class UserManager {
    // 移除 Firebase 初始化代码
    // func initializeFirebase() { ... }

    func registerForPushNotifications() {
        DeviceTokenManager.shared.registerForPushNotifications()
    }
}
```

---

### 4. **AppDelegate.swift** (或 App.swift) - 更新推送注册逻辑

**iOS App (UIKit)**:
```swift
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 移除 Firebase 初始化
        // FirebaseApp.configure()

        // 注册推送通知
        UNUserNotificationCenter.current().delegate = self
        DeviceTokenManager.shared.registerForPushNotifications()

        return true
    }

    // APNS Device Token 回调
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceTokenManager.shared.handleDeviceToken(deviceToken)
    }

    // 注册失败回调
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.handleRegistrationError(error)
    }

    // 前台收到推送
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // 用户点击推送
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("User tapped notification: \(userInfo)")
        completionHandler()
    }
}
```

**SwiftUI App**:
```swift
import SwiftUI
import UserNotifications

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.class) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        UNUserNotificationCenter.current().delegate = self
        DeviceTokenManager.shared.registerForPushNotifications()

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceTokenManager.shared.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.handleRegistrationError(error)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
```

---

### 5. **移除 GoogleService-Info.plist**

```bash
# 从项目中删除 Firebase 配置文件
cd /Users/xiaokangchen/Documents/VNN/sing-box-for-apple
find . -name "GoogleService-Info.plist" -delete

# 在 Xcode 中也移除引用
```

---

## 🔧 完整迁移步骤

### 步骤 1: 备份当前代码

```bash
cd /Users/xiaokangchen/Documents/VNN/sing-box-for-apple
git checkout -b feature/remove-firebase
git commit -am "backup: before removing Firebase"
```

---

### 步骤 2: 移除 Firebase 依赖

```bash
# 1. 编辑 Podfile，删除 Firebase 相关行
vim Podfile

# 2. 重新安装 Pods
pod deintegrate
pod install
```

---

### 步骤 3: 更新代码

按照上面的代码示例，依次修改：
1. ✅ `DeviceTokenManager.swift` - 移除 Firebase，使用原生 APNS
2. ✅ `UserManager.swift` - 移除 Firebase 初始化
3. ✅ `AppDelegate.swift` 或 `App.swift` - 更新推送注册逻辑

---

### 步骤 4: 删除 Firebase 配置文件

```bash
find . -name "GoogleService-Info.plist" -exec rm {} \;
```

在 Xcode 中：
- 右键 `GoogleService-Info.plist` → Delete → Move to Trash

---

### 步骤 5: 清理构建缓存

```bash
# 清理 Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData

# 在 Xcode 中
# Product → Clean Build Folder (Cmd+Shift+K)
```

---

### 步骤 6: 测试编译

```bash
# 命令行编译（iOS）
xcodebuild -workspace sing-box.xcworkspace -scheme SFI -configuration Debug build

# 或在 Xcode 中
# 选择 SFI scheme → Cmd+B 编译
```

---

### 步骤 7: 测试推送功能

1. **运行 App**（真机或模拟器）
2. **查看日志** - 应该看到 `APNS Device Token: xxxxxx`
3. **后端测试推送**:
   ```http
   POST /api/v1/user/device/test-push
   Authorization: Bearer YOUR_TOKEN
   {
     "title": "测试推送",
     "body": "Hello APNS",
     "sync": true
   }
   ```

---

## ⚠️ 注意事项

### 1. **推送权限**
确保在 Xcode 中启用了 Push Notifications capability：
- Target → Signing & Capabilities → + Capability → Push Notifications

### 2. **APNS 环境**
- **开发/测试**：使用沙箱环境（`APNS_PRODUCTION=false`）
- **生产**：使用正式环境（`APNS_PRODUCTION=true`）
- ⚠️ **沙箱 Token 不能用于生产环境！**

### 3. **Token 格式**
- APNS Device Token：64 字符 hex 字符串
- FCM Token：更长的字符串（约 152 字符）
- 后端会验证 Token 格式

### 4. **tvOS 支持**
tvOS 代码与 iOS 类似，只需将 `platform` 参数改为 `"tvos"`

---

## 📝 迁移检查清单

- [ ] 编辑 Podfile，移除 Firebase 依赖
- [ ] 运行 `pod deintegrate && pod install`
- [ ] 更新 `DeviceTokenManager.swift`
- [ ] 更新 `UserManager.swift`
- [ ] 更新 `AppDelegate.swift`
- [ ] 删除 `GoogleService-Info.plist`
- [ ] 清理构建缓存
- [ ] 编译通过（无 Firebase 相关错误）
- [ ] 真机测试获取 Device Token
- [ ] 测试推送接收功能
- [ ] 测试前台推送显示
- [ ] 测试后台推送唤醒
- [ ] tvOS 测试（如适用）

---

## 🐛 常见问题

### 问题 1: 编译错误 "Cannot find 'FirebaseCore' in scope"
**解决**：确保已运行 `pod install` 并重新打开 `.xcworkspace` 文件

### 问题 2: 获取不到 Device Token
**解决**：
- 检查推送权限是否授予
- 检查网络连接
- 查看 Xcode Console 的错误信息

### 问题 3: 推送未收到
**解决**：
- 确认后端环境配置正确（沙箱 vs 生产）
- 检查 Device Token 是否上传成功
- 使用 `push:diagnose` 命令测试后端配置

---

## 📚 参考资料

- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
- [Setting Up a Remote Notification Server](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Registering Your App with APNs](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns)

---

**创建时间**: 2025-10-11
**相关项目**: sing-box-for-apple
**后端迁移**: 已完成 ✅
