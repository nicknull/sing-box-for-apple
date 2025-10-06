# Repository Guidelines

## Project Structure & Module Organization
The Xcode workspace stitches together multiple Apple targets that share code via `ApplicationLibrary`. Core directories:
- `ApplicationLibrary/` holds cross-platform modules (auth, purchases, shared views) plus shared assets.
- `SFI/` contains the main iOS app (SwiftUI screens, delegates, entitlement files, and sync payloads).
- `SFT/` provides the tvOS client with its own views, models, and localized privacy disclosures.
- `SharedUserKit/` 提供用户认证、OAuth、与用户中心界面相关的共享实现。
- `SharedPaymentKit/` 抽离的支付/内购逻辑和示例视图，方便多终端共用。
- `SharedNotificationKit/` 封装设备 Token 管理等通知相关工具，统一 iOS/tvOS 推送逻辑。
- `Extension/`, `IntentsExtension/`, `WidgetExtension/`, and `SystemExtension/` deliver sidecar features; keep assets aligned with their owning target.
Assets and localization resources live in `Assets.xcassets` bundles and `Localizable.xcstrings`. Use `update_xcode_project.rb` whenever files move so the `.xcodeproj` stays in sync.

## Build, Test, and Development Commands
- `pod install`: resolves CocoaPods dependencies defined in `Podfile` before opening the workspace.
- `xcodebuild -workspace sing-box.xcworkspace -scheme SFI -configuration Debug build`: compile the iOS client for simulator runs.
- `xcodebuild -workspace sing-box.xcworkspace -scheme SFT -destination 'platform=tvOS Simulator,name=Apple TV' build`: validate the tvOS target stays green.
- `ruby update_xcode_project.rb`: refreshes Xcode target references after reorganising shared code.

## Coding Style & Naming Conventions
Swift code uses 4-space indentation and explicit access control. Types and protocols adopt PascalCase, members camelCase, and files mirror the primary type (`PurchaseView.swift`, `SharedNotificationKit/Services/DeviceTokenManager.swift`). Group SwiftUI views by feature folders, prefer dependency injection over singletons, and keep async work on structured concurrency. Run Xcode “Re-Indent” or `swift-format` (if installed) before committing large Swift changes.

## Testing Guidelines
Add XCTest bundles per scheme (e.g., `SFI Tests`). Name test files `<Feature>Tests.swift` and methods `test_<condition>_<result>()`. Run suites with `xcodebuild -workspace sing-box.xcworkspace -scheme SFI test` using an iOS simulator. Capture fixtures under `ApplicationLibrary/Service` for networked features, and document any manual smoke scenarios in PR notes when automation is not feasible.

## Commit & Pull Request Guidelines
Commits follow Conventional Commit prefixes (`docs:`, `chore:`, `refactor:`). Keep commits focused and include concise English summaries even when adding localized strings. Pull requests should describe platform impact, link issues, and attach simulator screenshots or clips for UI tweaks. Request reviews from the relevant module owners and confirm Pods and project files are regenerated when dependencies change.

## Configuration & Security Notes
Never commit personal `GoogleService-Info.plist`, subscription JSON payloads, or API keys. Use redacted samples like `subscribe.sample.json` and populate secrets via Xcode build settings or CI variables. Validate `.xcprivacy` declarations match data usage whenever sensitive APIs change.

## Team Communication
团队协作交流（PR 描述、代码评审反馈、Issue 更新）统一使用中文，确保语境一致并避免误解。

