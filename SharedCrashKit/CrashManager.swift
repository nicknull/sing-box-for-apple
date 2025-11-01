//
//  CrashManager.swift
//  SharedCrashKit
//
//  基于 PLCrashReporter 的崩溃日志收集管理器
//

import Foundation
import UIKit
import Defaults
import SystemConfiguration
import Moya
import Darwin
import CrashReporter


// MARK: - 崩溃响应模型
struct CrashReportResponse: Codable {
    let code: Int?
    let msg: String?
    let data: CrashReportData?
}

struct CrashReportData: Codable {
    let success: Bool
    let message: String?
    let crash_log_id: Int?
}

/// 基于 PLCrashReporter 的崩溃日志收集管理器
public class CrashManager {
    public static let shared = CrashManager()

    private var isInstalled = false
    private let queue = DispatchQueue(label: "com.gy.crashmanager", qos: .utility)
    private var eventLogs: [String] = []
    private let maxEventLogs = 50 // 最多保留50条事件日志
    private let crashLogsDirectoryName = "CrashLogs"
    private let sessionMarkerKey = "com.gy.crashmanager.activeSession"
    private let uncleanExitFlagKey = "com.gy.crashmanager.uncleanExit"
    private var crashReporter: PLCrashReporter?

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    private func iso8601String(from date: Date = Date()) -> String {
        CrashManager.iso8601Formatter.string(from: date)
    }

    /// 安装崩溃监听器
    public func install() {
        guard !isInstalled else {
            print("🔍 CrashManager already installed")
            return
        }

        print("🔍 CrashManager installing...")
        isInstalled = true

        do {
            setupSessionMonitoring()
            print("🔍 Session monitoring setup completed")

            configureCrashReporter()
            print("🔍 Crash reporter configured")

            // 启动时检查并上报本地崩溃日志
            queue.async {
                self.uploadPendingCrashLogs()
            }

            print("🔍 CrashManager installed successfully")
        } catch {
            print("❌ CrashManager installation failed: \(error)")
            isInstalled = false
        }
    }

    private func setupSessionMonitoring() {
        print("🔍 Setting up session monitoring...")
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: sessionMarkerKey) {
            defaults.set(false, forKey: sessionMarkerKey)
            defaults.set(true, forKey: uncleanExitFlagKey)
            print("🔍 Detected previous unclean exit")
        }

        defaults.set(true, forKey: sessionMarkerKey)

        if defaults.bool(forKey: uncleanExitFlagKey) {
            defaults.set(false, forKey: uncleanExitFlagKey)
            print("🔍 Processing unexpected termination crash...")
            queue.async {
                self.persistUnexpectedTerminationCrash()
            }
        }

        // 更安全的退出处理
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleProcessExit()
        }

        print("🔍 Session monitoring setup complete")
    }

    private func configureCrashReporter() {
        print("🔍 Configuring PLCrashReporter...")

        // 使用 BSD 信号处理类型，更稳定
        guard let config = PLCrashReporterConfig(signalHandlerType: .BSD, symbolicationStrategy: .all) else {
            print("❌ Failed to create PLCrashReporterConfig")
            return
        }

        guard let reporter = PLCrashReporter(configuration: config) else {
            print("❌ Failed to create PLCrashReporter instance")
            return
        }

        crashReporter = reporter
        print("🔍 PLCrashReporter instance created")

        if reporter.hasPendingCrashReport() {
            print("🔍 Found pending crash report, processing asynchronously...")
            queue.async {
                self.handlePendingCrashReport(crashReporter: reporter)
            }
        }

        do {
            try reporter.enableAndReturnError()
            print("🔐 PLCrashReporter enabled successfully")
        } catch {
            print("❌ Failed to enable PLCrashReporter: \(error)")
            crashReporter = nil
        }
    }

    private func handlePendingCrashReport(crashReporter: PLCrashReporter) {
        do {
            let reportData = try crashReporter.loadPendingCrashReportDataAndReturnError()
            let report = try PLCrashReport(data: reportData)
            let crashInfo = crashInfo(from: report)
            let userInfo = collectUserInfo()
            let deviceInfo = collectDeviceInfo()

            persistCrash(
                userInfo: userInfo,
                deviceInfo: deviceInfo,
                crashInfo: crashInfo,
                trigger: "plcrash_report"
            )

            crashReporter.purgePendingCrashReport()
        } catch {
            print("❌ Failed to process pending PLCrash report: \(error)")
        }
    }

    private func crashInfo(from report: PLCrashReport) -> [String: Any] {
        var crashInfo: [String: Any] = [:]

        if let uuidRef = report.uuidRef {
            crashInfo["crash_id"] = CFUUIDCreateString(nil, uuidRef) as String
        } else {
            crashInfo["crash_id"] = UUID().uuidString
        }

        if let timestamp = report.systemInfo?.timestamp {
            crashInfo["timestamp"] = iso8601String(from: timestamp)
        } else {
            crashInfo["timestamp"] = iso8601String()
        }

        crashInfo["type"] = "plcrash"

        if let signalInfo = report.signalInfo {
            crashInfo["signal_name"] = signalInfo.name
            crashInfo["signal_code"] = signalInfo.code
            crashInfo["signal_address"] = String(format: "0x%llx", signalInfo.address)
        }

        if let exceptionInfo = report.exceptionInfo {
            crashInfo["exception_name"] = exceptionInfo.exceptionName
            if let reason = exceptionInfo.exceptionReason {
                crashInfo["exception_reason"] = reason
            }

            if let frames = exceptionInfo.stackFrames as? [PLCrashReportStackFrameInfo], !frames.isEmpty {
                crashInfo["exception_stack_addresses"] = frames.map { String(format: "0x%llx", $0.instructionPointer) }
            }
        }

        if let applicationInfo = report.applicationInfo {
            crashInfo["app_identifier"] = applicationInfo.applicationIdentifier
            if let version = applicationInfo.applicationVersion {
                crashInfo["app_version"] = version
            }
            if let marketing = applicationInfo.applicationMarketingVersion {
                crashInfo["app_marketing_version"] = marketing
            }
        }

        if let systemInfo = report.systemInfo {
            crashInfo["os_name"] = systemInfo.operatingSystem
            if let version = systemInfo.operatingSystemVersion {
                crashInfo["os_version"] = version
            }
        }

        // 使用现代 API 生成格式化报告
        do {
            let formatted = try PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS)
            crashInfo["formatted_report"] = formatted
        } catch {
            print("⚠️ Failed to format crash report: \(error)")
        }

        return crashInfo
    }

    private func handleProcessExit() {
        UserDefaults.standard.set(false, forKey: sessionMarkerKey)
    }

    /// 收集用户信息
    private func collectUserInfo() -> [String: Any] {
        var userInfo: [String: Any] = [:]

        // 基础信息
        userInfo["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"
        userInfo["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "unknown"
        userInfo["bundle_id"] = Bundle.main.bundleIdentifier ?? "unknown"

        // 用户ID（如果有的话）
        if let userId = Defaults[.user_id] {
            userInfo["user_id"] = userId
        }

        // JWT Token 存在表示已登录
        if let token = Defaults[.jwt_token], !token.isEmpty {
            userInfo["is_logged_in"] = true
        } else {
            userInfo["is_logged_in"] = false
        }

        return userInfo
    }

    /// 收集设备信息
    private func collectDeviceInfo() -> [String: Any] {
        let device = UIDevice.current
        var deviceInfo: [String: Any] = [:]

        deviceInfo["model"] = device.model
        deviceInfo["system_name"] = device.systemName
        deviceInfo["system_version"] = device.systemVersion
        deviceInfo["device_name"] = device.name
        deviceInfo["identifier_for_vendor"] = device.identifierForVendor?.uuidString ?? "unknown"

        // 屏幕信息
        let screen = UIScreen.main
        deviceInfo["screen_size"] = "\(Int(screen.bounds.width))x\(Int(screen.bounds.height))"
        deviceInfo["screen_scale"] = screen.scale

        // 时区和语言
        deviceInfo["timezone"] = TimeZone.current.identifier
        deviceInfo["locale"] = Locale.current.identifier

        // 内存信息
        deviceInfo["memory_total"] = ProcessInfo.processInfo.physicalMemory

        // 存储信息
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            do {
                let attributes = try FileManager.default.attributesOfFileSystem(forPath: documentsPath)
                if let totalSize = attributes[.systemSize] as? NSNumber {
                    deviceInfo["storage_total"] = totalSize.int64Value
                }
                if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                    deviceInfo["storage_available"] = freeSize.int64Value
                }
            } catch {
                print("Failed to get storage info: \(error)")
            }
        }

        // 网络信息（简单判断）
        if let networkReachability = SCNetworkReachabilityCreateWithName(nil, "www.apple.com") {
            var flags: SCNetworkReachabilityFlags = []
            if SCNetworkReachabilityGetFlags(networkReachability, &flags) {
                if flags.contains(.reachable) {
                    if flags.contains(.isWWAN) {
                        deviceInfo["network_type"] = "Cellular"
                    } else {
                        deviceInfo["network_type"] = "WiFi"
                    }
                } else {
                    deviceInfo["network_type"] = "None"
                }
            }
        }

        return deviceInfo
    }

    private func persistCrash(userInfo: [String: Any], deviceInfo: [String: Any], crashInfo: [String: Any], trigger: String, markSessionTerminated: Bool = false) {
        var crashData: [String: Any] = [
            "user_info": userInfo,
            "device_info": deviceInfo,
            "crash_info": crashInfo,
            "trigger": trigger,
            "timestamp": iso8601String()
        ]

        if !eventLogs.isEmpty {
            crashData["recent_events"] = eventLogs
        }

        guard let sanitizedCrashData = sanitizedJSONObject(from: crashData) as? [String: Any] else {
            print("❌ Failed to sanitize crash data for JSON serialization")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sanitizedCrashData, options: [])
            let fileURL = try crashFileURL()
            try jsonData.write(to: fileURL, options: .atomic)
            print("💾 Crash saved to local: \(fileURL.lastPathComponent)")

            if markSessionTerminated {
                UserDefaults.standard.set(false, forKey: sessionMarkerKey)
            }

            queue.async {
                self.uploadCrashFile(at: fileURL)
            }
        } catch {
            print("❌ Failed to persist crash: \(error)")
        }
    }

    private func crashFileURL() throws -> URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "CrashManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取文档目录"])
        }

        let crashLogsDir = documentsPath.appendingPathComponent(crashLogsDirectoryName)
        try FileManager.default.createDirectory(at: crashLogsDir, withIntermediateDirectories: true)

        let filename = "crash_\(UUID().uuidString).json"
        return crashLogsDir.appendingPathComponent(filename)
    }

    private func sanitizedJSONObject(from value: Any) -> Any? {
        switch value {
        case is NSNull:
            return NSNull()
        case let bool as Bool:
            return bool
        case let string as String:
            return string
        case let int as Int:
            return int
        case let int as Int8:
            return NSNumber(value: int)
        case let int as Int16:
            return NSNumber(value: int)
        case let int as Int32:
            return NSNumber(value: int)
        case let int as Int64:
            return NSNumber(value: int)
        case let uint as UInt:
            return NSNumber(value: uint)
        case let uint as UInt8:
            return NSNumber(value: uint)
        case let uint as UInt16:
            return NSNumber(value: uint)
        case let uint as UInt32:
            return NSNumber(value: uint)
        case let uint as UInt64:
            return NSNumber(value: uint)
        case let double as Double:
            return double
        case let float as Float:
            return NSNumber(value: float)
        case let cgFloat as CGFloat:
            return NSNumber(value: Double(cgFloat))
        case let number as NSNumber:
            return number
        case let date as Date:
            return iso8601String(from: date)
        case let url as URL:
            return url.absoluteString
        case let uuid as UUID:
            return uuid.uuidString
        case let data as Data:
            return data.base64EncodedString()
        case let dict as [String: Any]:
            var sanitized: [String: Any] = [:]
            for (key, value) in dict {
                if let sanitizedValue = sanitizedJSONObject(from: value) {
                    sanitized[key] = sanitizedValue
                }
            }
            return sanitized
        case let dict as [AnyHashable: Any]:
            var sanitized: [String: Any] = [:]
            for (key, value) in dict {
                guard let keyString = key as? String else { continue }
                if let sanitizedValue = sanitizedJSONObject(from: value) {
                    sanitized[keyString] = sanitizedValue
                }
            }
            return sanitized
        case let array as [Any]:
            return array.compactMap { sanitizedJSONObject(from: $0) }
        case let array as NSArray:
            return array.compactMap { sanitizedJSONObject(from: $0) }
        case let error as any Error:
            return error.localizedDescription
        default:
            return String(describing: value)
        }
    }

    /// 上传待处理的崩溃日志
    private func uploadPendingCrashLogs() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let crashLogsDir = documentsPath.appendingPathComponent(crashLogsDirectoryName)

        do {
            let crashFiles = try FileManager.default.contentsOfDirectory(at: crashLogsDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            for crashFile in crashFiles {
                uploadCrashFile(at: crashFile)
            }
        } catch {
            // 目录不存在或无法读取，忽略
            return
        }
    }

    /// 上传单个崩溃文件
    private func uploadCrashFile(at fileURL: URL) {
        do {
            let data = try Data(contentsOf: fileURL)
            let crashData = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let crashInfo = crashData else {
                print("❌ Invalid crash file format: \(fileURL.lastPathComponent)")
                try? FileManager.default.removeItem(at: fileURL)
                return
            }

            uploadCrashDataAsync(crashData: crashInfo) { success in
                if success {
                    try? FileManager.default.removeItem(at: fileURL)
                    print("✅ Uploaded and removed crash file: \(fileURL.lastPathComponent)")
                } else {
                    print("❌ Failed to upload crash file: \(fileURL.lastPathComponent)")
                }
            }

        } catch {
            print("❌ Failed to read crash file: \(error)")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// 异步上报崩溃数据
    private func uploadCrashDataAsync(crashData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let userInfo = crashData["user_info"] as? [String: Any],
              let deviceInfo = crashData["device_info"] as? [String: Any],
              let crashInfo = crashData["crash_info"] as? [String: Any] else {
            completion(false)
            return
        }

        NetworkService.shared.request(
            AQAPIService.reportCrash(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo)
        ) { result in
            switch result {
            case .success(let context):
                guard context.httpStatusCode == 200 else {
                    print("❌ CrashManager async upload failed: HTTP \(context.httpStatusCode)")
                    completion(false)
                    return
                }

                if let payloadString = context.payloadString,
                   let data = payloadString.data(using: .utf8),
                   let response = try? JSONDecoder().decode(CrashReportResponse.self, from: data) {
                    if response.data?.success == true {
                        print("✅ CrashManager async upload successful")
                        completion(true)
                        return
                    }

                    if let message = response.msg, !message.isEmpty {
                        print("✅ CrashManager async upload successful: \(message)")
                        completion(true)
                        return
                    }
                }

                print("✅ CrashManager async upload successful (no structured payload)")
                completion(true)

            case .failure(let error):
                print("❌ CrashManager async upload failed: \(error.message)")
                completion(false)
            }
        }
    }
    /// 验证 PLCrashReporter 是否正常初始化
    public func verifyInstallation() -> Bool {
        guard isInstalled else {
            print("❌ CrashManager not installed")
            return false
        }

        guard let reporter = crashReporter else {
            print("❌ PLCrashReporter instance not found")
            return false
        }

        // 检查 PLCrashReporter 是否启用
        // 注意：PLCrashReporter 1.12.0 版本的 API 可能没有直接的 isEnabled 方法
        // 我们通过能否正常创建实例来判断
        print("✅ CrashManager verification successful")
        print("📊 PLCrashReporter status: initialized and configured")
        return true
    }

    /// 触发一次测试崩溃，用于验证崩溃日志捕获与上报链路。
    public func triggerTestCrash(reason: String = "测试触发崩溃", signal: Int32 = SIGABRT) {
#if DEBUG
        guard isInstalled else {
            print("⚠️ CrashManager 未安装，无法触发测试崩溃")
            return
        }

        print("🧪 CrashManager 即将触发测试崩溃: signal=\(signal), reason=\(reason)")
        logEvent(name: "force_crash_trigger", parameters: ["reason": reason])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            raise(signal)
        }
#else
        NSLog("⚠️ triggerTestCrash 仅在 Debug 构建可用: %@", reason)
#endif
    }

    /// 手动上报自定义崩溃信息
    /// 用于捕获非致命错误或特定业务逻辑错误
    public func reportCustomCrash(
        errorName: String,
        errorMessage: String,
        stackTrace: [String],
        additionalInfo: [String: Any]? = nil
    ) {
        queue.async {
            let userInfo = self.collectUserInfo()
            let deviceInfo = self.collectDeviceInfo()

            var crashInfo: [String: Any] = [
                "crash_id": UUID().uuidString,
                "timestamp": self.iso8601String(),
                "type": "custom",
                "exception_name": errorName,
                "exception_reason": errorMessage,
                "stack_trace": stackTrace.joined(separator: "\n"),
                "thread_name": Thread.current.name ?? "unknown",
                "is_main_thread": Thread.isMainThread,
                "is_custom_report": true
            ]

            // 添加额外信息
            if let additionalInfo = additionalInfo {
                crashInfo["additional_info"] = additionalInfo
            }

            // 添加最近的事件日志作为上下文
            if !self.eventLogs.isEmpty {
                crashInfo["recent_events"] = self.eventLogs
            }

            self.persistCrash(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo, trigger: "custom")
        }
    }

    /// 记录关键业务事件（可用于崩溃分析上下文）
    public func logEvent(name: String, parameters: [String: Any] = [:]) {
        queue.async {
            let timestamp = self.iso8601String()
            let eventDescription = "\(timestamp): \(name) - \(parameters)"

            self.eventLogs.append(eventDescription)

            // 保持事件日志数量在限制内
            if self.eventLogs.count > self.maxEventLogs {
                self.eventLogs.removeFirst(self.eventLogs.count - self.maxEventLogs)
            }

            print("📝 CrashManager logged event: \(name)")
        }
    }
}

// MARK: - Defaults Keys Extension
extension Defaults.Keys {
    static let user_id = Key<String?>("user_id")
    static let jwt_token = Key<String?>("jwt_token")
//    static let host = Key<String>("host", default: "")
}

// MARK: - Unexpected Termination Support
extension CrashManager {
    private func persistUnexpectedTerminationCrash() {
        let userInfo = collectUserInfo()
        let deviceInfo = collectDeviceInfo()

        let crashInfo: [String: Any] = [
            "crash_id": UUID().uuidString,
            "timestamp": iso8601String(),
            "type": "unexpected_exit",
            "reason": "Detected unclean shutdown",
            "thread_name": Thread.current.name ?? "unknown",
            "is_main_thread": Thread.isMainThread
        ]

        persistCrash(
            userInfo: userInfo,
            deviceInfo: deviceInfo,
            crashInfo: crashInfo,
            trigger: "unclean_exit",
            markSessionTerminated: true
        )

        UserDefaults.standard.set(true, forKey: sessionMarkerKey)
    }
}
