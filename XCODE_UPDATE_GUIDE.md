# Xcode 项目文件更新指南

## ⚠️ 重要提示
代码已在文件系统中移动到 ApplicationLibrary，但需要在 Xcode 中手动更新项目引用。

---

## 📋 操作步骤

### 步骤 1: 打开 Xcode 项目
```bash
cd /Users/xiaokangchen/Documents/GitHub/sing-box-for-apple
open sing-box.xcworkspace
```

### 步骤 2: 添加新文件到 ApplicationLibrary

#### 2.1 添加 OAuth 目录
1. 在 Xcode 左侧导航栏中找到 **ApplicationLibrary** 文件夹
2. 右键点击 ApplicationLibrary → **Add Files to "ApplicationLibrary"...**
3. 选择 `ApplicationLibrary/OAuth` 文件夹
4. ✅ 勾选 **"Create groups"**
5. ✅ 勾选 **Target: ApplicationLibrary**
6. 点击 **Add**

**预期添加的文件：**
- AppleSignInManager.swift
- GoogleSignInManager.swift
- GitHubSignInManager.swift
- OAuthManager.swift
- OAuthBindingManager.swift

#### 2.2 添加 PurchaseX 目录
1. 右键点击 ApplicationLibrary → **Add Files to "ApplicationLibrary"...**
2. 选择 `ApplicationLibrary/PurchaseX` 文件夹
3. ✅ 勾选 **"Create groups"**
4. ✅ 勾选 **Target: ApplicationLibrary**
5. 点击 **Add**

**预期添加的文件：**
- IAPOrderManager.swift
- PurchaseXHelper/
  - PurchaseXManager.swift
  - PXDataPersistence.swift
  - PurchaseXException.swift
  - PurchaseXNotification.swift
  - PurchaseXState.swift
- Util/
  - PXLog.swift

#### 2.3 添加 Service/DeviceTokenManager.swift
1. 在 ApplicationLibrary 下找到 **Service** 文件夹
2. 右键点击 Service → **Add Files to "ApplicationLibrary"...**
3. 选择 `ApplicationLibrary/Service/DeviceTokenManager.swift`
4. ✅ 勾选 **Target: ApplicationLibrary**
5. 点击 **Add**

#### 2.4 添加 Views 文件
1. 在 ApplicationLibrary 下找到 **Views** 文件夹
2. 右键点击 Views → **Add Files to "ApplicationLibrary"...**
3. 选择以下文件：
   - `ApplicationLibrary/Views/AccountBindingView.swift`
   - `ApplicationLibrary/Views/PurchaseView.swift`
4. ✅ 勾选 **Target: ApplicationLibrary**
5. 点击 **Add**

---

### 步骤 3: 清理旧引用

#### 3.1 删除 SFI 中的旧引用
在 Xcode 中找到 **SFI** 文件夹，删除以下引用（只删除引用，不删除文件）：
- ❌ SFI/OAuth/ (整个文件夹)
- ❌ SFI/PurchaseX/ (整个文件夹)
- ❌ SFI/AccountBindingView.swift
- ❌ SFI/PurchaseView.swift

**操作方式：**
1. 选中文件/文件夹
2. 按 Delete 键
3. 选择 **"Remove Reference"**（不要选 "Move to Trash"）

#### 3.2 删除 SFT 中的旧引用
在 Xcode 中找到 **SFT** 文件夹，删除以下引用（只删除引用，不删除文件）：
- ❌ SFT/OAuth/ (整个文件夹)
- ❌ SFT/PurchaseX/ (整个文件夹)
- ❌ SFT/FCMTokenManager.swift
- ❌ SFT/AccountBindingView.swift
- ❌ SFT/PurchaseView.swift

---

### 步骤 4: 验证 Target Membership

#### 4.1 检查 ApplicationLibrary 文件
选择 ApplicationLibrary 中的任意新增文件，在右侧 **File Inspector** 中检查：
- ✅ **Target Membership** 应该包含 **ApplicationLibrary**

#### 4.2 验证 Build Phases
1. 选择项目根节点 **sing-box**
2. 选择 **ApplicationLibrary** target
3. 进入 **Build Phases** 标签
4. 展开 **Compile Sources**
5. 确认所有新增的 .swift 文件都在列表中：
   - OAuth/*.swift (5 个文件)
   - PurchaseX/**/*.swift (7 个文件)
   - Service/DeviceTokenManager.swift (1 个文件)
   - Views/AccountBindingView.swift (1 个文件)
   - Views/PurchaseView.swift (1 个文件)

**预期总数：15 个新文件**

---

### 步骤 5: 验证 SFI 和 SFT 的依赖

#### 5.1 检查 SFI target
1. 选择 **SFI** target
2. 进入 **General** 标签
3. 在 **Frameworks, Libraries, and Embedded Content** 中确认：
   - ✅ **ApplicationLibrary.framework** 已添加

#### 5.2 检查 SFT target
1. 选择 **SFT** target
2. 进入 **General** 标签
3. 在 **Frameworks, Libraries, and Embedded Content** 中确认：
   - ✅ **ApplicationLibrary.framework** 已添加

---

### 步骤 6: 编译测试

#### 6.1 编译 ApplicationLibrary
1. 选择 scheme: **ApplicationLibrary**
2. 选择目标设备: **Any iOS Device** 或模拟器
3. 按 **Cmd + B** 编译
4. 确认无错误

#### 6.2 编译 SFI (iOS)
1. 选择 scheme: **SFI**
2. 选择目标设备: **iPhone 15 Pro** 或其他模拟器
3. 按 **Cmd + B** 编译
4. 确认无错误

#### 6.3 编译 SFT (tvOS)
1. 选择 scheme: **SFT**
2. 选择目标设备: **Apple TV 4K** 或模拟器
3. 按 **Cmd + B** 编译
4. 确认无错误

---

## ❗ 常见问题

### 问题 1: "No such module 'ApplicationLibrary'"
**原因**: SFI 或 SFT 没有正确链接 ApplicationLibrary
**解决**:
1. 选择 SFI/SFT target
2. General → Frameworks, Libraries, and Embedded Content
3. 点击 + 号，添加 ApplicationLibrary.framework

### 问题 2: "Use of undeclared type 'OAuthManager'"
**原因**: 文件没有正确添加到 ApplicationLibrary target
**解决**:
1. 选择该文件
2. File Inspector → Target Membership
3. 勾选 ApplicationLibrary

### 问题 3: "Duplicate symbols"
**原因**: 文件被同时添加到多个 target
**解决**:
1. 选择重复的文件
2. File Inspector → Target Membership
3. 只保留 ApplicationLibrary，取消其他勾选

### 问题 4: 编译错误 "Cannot find 'DeviceTokenManager' in scope"
**原因**: SFT 中可能还有对 FCMTokenManager 的引用
**解决**:
1. 全局搜索 `FCMTokenManager`
2. 替换为 `DeviceTokenManager`

---

## ✅ 验证清单

完成上述步骤后，确认以下内容：

### ApplicationLibrary
- [ ] OAuth/ 文件夹显示在 Xcode 中（5 个文件）
- [ ] PurchaseX/ 文件夹显示在 Xcode 中（7 个文件）
- [ ] Service/DeviceTokenManager.swift 显示在 Xcode 中
- [ ] Views/AccountBindingView.swift 显示在 Xcode 中
- [ ] Views/PurchaseView.swift 显示在 Xcode 中
- [ ] ApplicationLibrary target 编译成功

### SFI
- [ ] 旧的 OAuth/ 引用已删除
- [ ] 旧的 PurchaseX/ 引用已删除
- [ ] 旧的 AccountBindingView.swift 引用已删除
- [ ] 旧的 PurchaseView.swift 引用已删除
- [ ] SFI target 编译成功

### SFT
- [ ] 旧的 OAuth/ 引用已删除
- [ ] 旧的 PurchaseX/ 引用已删除
- [ ] 旧的 FCMTokenManager.swift 引用已删除
- [ ] 旧的 AccountBindingView.swift 引用已删除
- [ ] 旧的 PurchaseView.swift 引用已删除
- [ ] SFT target 编译成功

---

## 📊 预期结果

完成后，Xcode 项目结构应该是：

```
sing-box.xcworkspace
├── sing-box.xcodeproj
│   ├── SFI (target)
│   │   ├── LoginView.swift
│   │   ├── DashBoardView.swift
│   │   └── (其他 iOS 特定文件)
│   ├── SFT (target)
│   │   ├── LoginView.swift
│   │   ├── DashBoardView.swift
│   │   └── (其他 tvOS 特定文件)
│   └── ApplicationLibrary (target)
│       ├── OAuth/               ✅ 新增
│       ├── PurchaseX/           ✅ 新增
│       ├── Service/
│       │   └── DeviceTokenManager.swift  ✅ 新增
│       └── Views/
│           ├── AccountBindingView.swift  ✅ 新增
│           └── PurchaseView.swift        ✅ 新增
```

---

## 🚀 完成后

提交 Xcode 项目文件的修改：

```bash
git add sing-box.xcodeproj/project.pbxproj
git commit -m "chore: 更新 Xcode 项目文件引用

- 将 OAuth、PurchaseX、Views 添加到 ApplicationLibrary target
- 删除 SFI 和 SFT 中的旧文件引用
- 更新 Build Phases 和 Target Membership
"
```

---

**操作时间**: 预计 10-15 分钟
**难度**: ⭐⭐ (中等)
**重要性**: ⭐⭐⭐⭐⭐ (非常重要 - 不完成此步骤代码无法编译)
