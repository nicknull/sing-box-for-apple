//
//  CrashManager.swift
//  SharedCrashKit
//
//  崩溃日志收集管理器
//

import Foundation
import UIKit
import Defaults
import SystemConfiguration
import Moya
import Darwin
import PLCrashReporter


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

/// 崩溃日志收集管理器
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

    private init() {}

    /// 安装崩溃监听器
    public func install() {
        guard !isInstalled else { return }
        isInstalled = true

        setupSessionMonitoring()

        configureCrashReporter()

        // 启动时检查并上报本地崩溃日志
        queue.async {
            self.uploadPendingCrashLogs()
        }

        print("🔍 CrashManager installed successfully")
    }

    private func setupSessionMonitoring() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: sessionMarkerKey) {
            defaults.set(false, forKey: sessionMarkerKey)
            defaults.set(true, forKey: uncleanExitFlagKey)
        }

        defaults.set(true, forKey: sessionMarkerKey)

        if defaults.bool(forKey: uncleanExitFlagKey) {
            defaults.set(false, forKey: uncleanExitFlagKey)
            queue.async {
                self.persistUnexpectedTerminationCrash()
            }
        }

        atexit_b {
            CrashManager.shared.handleProcessExit()
        }
    }

    private func configureCrashReporter() {
        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
        crashReporter = PLCrashReporter(configuration: config)

        guard let crashReporter else {
            print("⚠️ Failed to instantiate PLCrashReporter")
            return
        }

        if crashReporter.hasPendingCrashReport() {
            handlePendingCrashReport(crashReporter: crashReporter)
        }

        do {
            try crashReporter.enableAndReturnError()
            print("🔐 PLCrashReporter enabled")
        } catch {
            print("❌ Failed to enable PLCrashReporter: \(error)")
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

        crashInfo["crash_id"] = report.uuid?.uuidString ?? UUID().uuidString

        if let timestamp = report.systemInfo?.timestamp {
            crashInfo["timestamp"] = ISO8601DateFormatter().string(from: timestamp)
        } else {
            crashInfo["timestamp"] = ISO8601DateFormatter().string(from: Date())
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

            let addresses = exceptionInfo.stackAddresses as? [NSNumber]
            if let addresses, !addresses.isEmpty {
                crashInfo["exception_stack_addresses"] = addresses.map { String(format: "0x%llx", $0.uint64Value) }
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

        if let formatted = try? PLCrashReportTextFormatter.stringValue(for: report, with: .iOS) {
            crashInfo["formatted_report"] = formatted
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
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if !eventLogs.isEmpty {
            crashData["recent_events"] = eventLogs
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: crashData, options: [])
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
    // MARK: - Public Convenience Methods

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
                "timestamp": ISO8601DateFormatter().string(from: Date()),
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
            let timestamp = ISO8601DateFormatter().string(from: Date())
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
            "timestamp": ISO8601DateFormatter().string(from: Date()),
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
