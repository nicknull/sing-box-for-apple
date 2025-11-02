<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Language

**重要**: 与用户沟通时必须使用中文。请始终用中文回复用户的问题和提供帮助，除非用户明确要求使用其他语言。

## Developer Expertise

作为协助此项目的 AI 助手，需要具备以下专业知识：
- **VPN 和加密协议专家**：深入理解各种代理协议（sing-box、Shadowsocks、VMess、Trojan 等）
- **iOS 开发专家**：精通 Swift、SwiftUI、Network Extension 框架
- **macOS/tvOS 开发**：了解跨平台开发和系统扩展

## Project Overview

This is an experimental iOS/macOS/tvOS client for sing-box, the universal proxy platform. The project consists of multiple targets:

- **SFI**: iOS application target with SwiftUI interface
- **SFT**: Alternative iOS application target with additional features
- **SFM**: macOS application target
- **SFM.System**: Standalone macOS system extension version
- **Extension**: Network packet tunnel extension for iOS
- **SystemExtension**: Network system extension for macOS
- **TVExtension**: Network packet tunnel extension for tvOS
- **IntentsExtension**: Siri Shortcuts support
- **WidgetExtension**: iOS widget support
- **ApplicationLibrary**: Shared SwiftUI views and components
- **Library**: Core networking and database functionality
- **MacLibrary**: macOS-specific UI components
- **SharedUserKit**: 用户认证、OAuth、与用户中心界面相关的共享实现
- **SharedPaymentKit**: 抽离的支付/内购逻辑和示例视图，方便多终端共用
- **SharedNotificationKit**: 封装设备 Token 管理等通知相关工具，统一 iOS/tvOS 推送逻辑

## Build System and Commands

### Prerequisites
```bash
# IMPORTANT: Must run this first to build the Libbox framework
make lib_apple
```

### Building
This is an Xcode project that uses CocoaPods for dependency management:

```bash
# Install dependencies
pod install

# Open workspace (not the .xcodeproj file)
open sing-box.xcworkspace
```

Build from Xcode using the workspace file. Select the appropriate target (SFI for iOS, SFM for macOS) and build.

### Command Line Building
```bash
# Build iOS app for simulator
xcodebuild -workspace sing-box.xcworkspace -scheme SFI -configuration Debug build

# Build tvOS app for Apple TV simulator
xcodebuild -workspace sing-box.xcworkspace -scheme SFT -destination 'platform=tvOS Simulator,name=Apple TV' build

# Run iOS tests
xcodebuild -workspace sing-box.xcworkspace -scheme SFI test

# Update Xcode project references after file reorganization
ruby update_xcode_project.rb
```

### Development Workflow
1. 修改代码后，在 Xcode 中选择对应的 target (SFI/SFT/SFM)
2. 连接真机或选择模拟器
3. 点击 Run (Cmd+R) 进行构建和运行
4. 对于 Network Extension 的修改，需要重新安装 VPN 配置

## Known Issues and Solutions

### Multiple fullScreenCover Conflict
如果遇到 "Currently, only presenting a single sheet is supported" 错误，这是因为应用中同时使用了多个 fullScreenCover。

**最佳解决方案**（采用统一状态管理）：
1. 在 `SFI/Application.swift` 中创建 `AppStateManager` 来管理应用的整体状态流程
2. 使用 `AppState` 枚举定义应用状态：sync（同步）、login（登录）、main（主界面）
3. 在应用启动时统一判断状态优先级：
   - 首先检查是否需要显示 SyncView（基于时间间隔）
   - 如果不需要同步，检查用户是否已登录
   - 根据状态直接显示对应的根视图，而不是使用 fullScreenCover

**优势**：
- 逻辑更清晰，状态管理统一
- 避免了多个 fullScreenCover 同时存在的问题
- 应用流程更加直观：同步 → 登录 → 主界面

### SyncView 架构重构
SyncView 已重构以适应新的状态管理架构：

**架构改进**：
1. **状态管理集成**：通过 `@EnvironmentObject` 直接与 `AppStateManager` 通信
2. **独立状态枚举**：使用 `SyncState` 管理同步过程的详细状态
3. **清晰的职责分离**：SyncView 专注于同步逻辑，状态流转交给 AppStateManager

**用户体验优化**：
1. **智能时机判断**：考虑首次打开时网络权限可能还在申请中，添加延迟等待
2. **网络状态监控**：使用 `MonitoringNetworkState` 实时监控网络连接状态
3. **超时处理**：设置30秒请求超时，避免无限等待
4. **视觉反馈**：清晰的状态指示器和图标，区分不同的同步阶段
5. **用户控制**：
   - 10秒后显示"跳过此步骤"按钮
   - 失败时提供"重试"选项
   - 成功后自动进入下一步（2秒延迟）

**状态流程**：
- initializing → waitingNetwork/syncing → success/failed → 下一步
- 网络变化会智能地触发状态转换
- 同步完成后通过 `appStateManager.syncCompleted()` 进入下一阶段

### LoginView 状态管理集成
LoginView 也已适应新的状态管理架构：

**架构改进**：
1. **移除 dismiss() 依赖**：不再使用 `@Environment(\.dismiss)`，改为通过 `AppStateManager` 管理状态
2. **集成 AppStateManager**：登录成功后通过 `appStateManager.loginCompleted()` 通知状态管理器
3. **改进错误处理**：
   - 添加输入验证（用户名和密码不能为空）
   - 统一的错误信息处理和显示
   - 更好的网络错误提示

**状态流转**：
- 登录成功 → `appStateManager.loginCompleted()` → 进入主界面
- 所有UI状态更新都在主线程中执行
- 保持了原有的用户体验（加载状态、错误提示等）

### UserView 状态管理集成
UserView 中的登出逻辑也已适应新的状态管理架构：

**改进内容**：
1. **移除 dismiss() 依赖**：不再使用 `@Environment(\.dismiss)`
2. **集成 AppStateManager**：通过 `@EnvironmentObject` 获取状态管理器
3. **登出流程优化**：
   - 用户点击登出确认后调用 `userManager.logout()` 清除用户数据
   - 调用 `appStateManager.userLoggedOut()` 直接跳转到登录页面
   - 避免了复杂的状态检查，直接进入登录状态

**环境对象传递链**：
- Application → DashBoardView → UserView
- 确保 AppStateManager 在整个导航链中都可访问

### CodeScannerView 修复
修复了 UserView 中二维码扫描无法返回的问题：

**问题原因**：
- 原始实现缺少导航栏和取消按钮
- 没有正确处理扫描失败的情况
- 用户界面缺少必要的返回机制

**修复方案**：
1. **添加导航栏**：使用 NavigationView 包装 CodeScannerView
2. **添加取消按钮**：使用 toolbar 添加左上角取消按钮
3. **完善扫描处理**：
   - 使用独立的 `handleScanResult` 方法处理结果
   - 区分成功和失败情况，提供不同的用户反馈
   - 添加成功和错误 alert 提示
4. **用户体验优化**：
   - 添加扫描提示文字overlay
   - 使用 `scanMode: .once` 避免重复扫描
   - 显示扫描框 `showViewfinder: true`

**CodeScanner 配置**：
- 库版本：2.5.2 (来自 twostraws/CodeScanner)
- 扫描类型：QR码
- 扫描模式：单次扫描后自动关闭

### Testing
Testing is performed through Xcode's XCTest framework:

```bash
# Run iOS tests
xcodebuild -workspace sing-box.xcworkspace -scheme SFI test

# Run tests for specific target
xcodebuild -workspace sing-box.xcworkspace -scheme SFT test
```

**Test Organization**:
- Add XCTest bundles per scheme (e.g., `SFI Tests`)
- Name test files `<Feature>Tests.swift` and methods `test_<condition>_<result>()`
- Capture fixtures under `ApplicationLibrary/Service` for networked features
- Document manual smoke test scenarios in PR notes when automation is not feasible

## Architecture

### Core Components

#### Library Module (`Library/`)
- **Database layer**: Uses GRDB for SQLite operations
  - `ProfileManager`: Core database operations for VPN profiles
  - `Profile`: Model representing VPN configurations with CRUD operations
  - `SharedPreferences`: App settings and preferences storage
- **Network layer**: VPN connection management
  - `ExtensionProvider`: Base class for packet tunnel providers
  - `ExtensionPlatformInterface`: Bridge between Swift and sing-box core
  - `CommandClient`: Communication with VPN service
- **Discovery**: Profile server and network socket utilities

#### Application Targets
- **SFI**: Main iOS app with user authentication, dashboard, and profile management
- **SFT**: iOS app variant with additional API integration and ticketing system
- **SFM**: macOS app with menu bar interface and sidebar navigation
- **Extensions**: Packet tunnel providers that implement the actual VPN functionality

#### UI Architecture
- SwiftUI-based with shared components in `ApplicationLibrary`
- Environment objects for state management (`ExtensionEnvironments`, `UserManager`)
- Custom navigation with compatibility layers for different iOS versions
- Dashboard-centric design with connection status, profile management, and settings

### Key Dependencies
- **Libbox.xcframework**: Core sing-box functionality (C bindings)
- **Firebase**: Remote config, analytics, messaging
- **SwiftyJSON**: JSON parsing
- **Moya/Alamofire**: Network layer
- **GRDB**: Database operations
- **Defaults**: User preferences
- **Lottie**: Animations

### Data Flow
1. VPN profiles stored in SQLite database via GRDB
2. Network extensions communicate with sing-box core via Libbox framework
3. UI updates through SwiftUI state management and environment objects
4. Settings persisted using Defaults library
5. Remote configuration via Firebase Remote Config

### Platform-Specific Notes
- macOS versions support both app extension and system extension modes
- iOS includes Control Center integration (iOS 18+) and widget support
- tvOS has dedicated packet tunnel extension
- Location services integration on macOS for WiFi state detection

## Important Notes

### VPN 协议和 sing-box 核心
- sing-box 是一个通用的代理平台，支持多种协议（Shadowsocks、VMess、Trojan、Hysteria 等）
- Libbox.xcframework 是 sing-box 的核心库，通过 C bindings 与 Swift 交互
- Network Extension 通过 ExtensionProvider 类与 sing-box 核心通信
- VPN 配置文件以 JSON 格式存储在 SQLite 数据库中

### State Management Pattern
项目使用 AppStateManager 进行全局状态管理：
- **AppState 枚举**：sync（同步）、login（登录）、main（主界面）
- **状态流转**：sync → login → main
- **环境对象传递链**：Application → DashBoardView → UserView/SettingsView
- 避免使用多个 fullScreenCover，改用状态驱动的视图切换

### Network Extension 开发注意事项
1. Extension target 与主 app 运行在不同的进程中
2. 通过 App Group 共享数据（SQLite 数据库、UserDefaults）
3. ExtensionProvider 是 NEPacketTunnelProvider 的子类
4. CommandClient 用于主 app 与 extension 之间的通信
5. 修改 extension 代码后需要重新安装 VPN 配置才能生效

## File Organization
- Target-specific code in individual directories (SFI/, SFM/, etc.)
- Shared Swift code in Library/ and ApplicationLibrary/
- Extensions in dedicated directories with entitlements
- CocoaPods dependencies in Pods/ directory
- Localizable strings in Localizable.xcstrings