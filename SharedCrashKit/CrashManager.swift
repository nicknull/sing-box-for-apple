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

    private init() {}

    /// 安装崩溃监听器
    public func install() {
        guard !isInstalled else { return }
        isInstalled = true

        // 安装异常处理器
        NSSetUncaughtExceptionHandler { exception in
            CrashManager.shared.handleException(exception)
        }

        // 安装信号处理器
        installSignalHandlers()

        // 启动时检查并上报本地崩溃日志
        queue.async {
            self.uploadPendingCrashLogs()
        }

        print("🔍 CrashManager installed successfully")
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

    /// 收集崩溃信息
    private func collectCrashInfo(exception: NSException?, signal: Int32?) -> [String: Any] {
        var crashInfo: [String: Any] = [:]

        crashInfo["crash_id"] = UUID().uuidString
        crashInfo["timestamp"] = ISO8601DateFormatter().string(from: Date())

        if let exception = exception {
            crashInfo["type"] = "exception"
            crashInfo["exception_name"] = exception.name.rawValue
            crashInfo["exception_reason"] = exception.reason ?? ""
            crashInfo["stack_trace"] = exception.callStackSymbols.joined(separator: "\n")
        } else if let signal = signal {
            crashInfo["type"] = "signal"
            crashInfo["signal"] = signal
            crashInfo["signal_name"] = getSignalName(signal)
            crashInfo["stack_trace"] = Thread.callStackSymbols.joined(separator: "\n")
        }

        // 线程信息
        crashInfo["thread_name"] = Thread.current.name ?? "unknown"
        crashInfo["is_main_thread"] = Thread.isMainThread

        return crashInfo
    }

    /// 处理异常
    private func handleException(_ exception: NSException) {
        let userInfo = collectUserInfo()
        let deviceInfo = collectDeviceInfo()
        let crashInfo = collectCrashInfo(exception: exception, signal: nil)

        // 立即上报
        reportCrashSync(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo)
    }

    /// 处理信号
    private func handleSignal(_ signalCode: Int32) {
        let userInfo = collectUserInfo()
        let deviceInfo = collectDeviceInfo()
        let crashInfo = collectCrashInfo(exception: nil, signal: signalCode)

        // 立即上报
        reportCrashSync(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo)

        // 恢复默认处理并重新触发，让系统照常终止进程
        Darwin.signal(signalCode, SIG_DFL)
        kill(getpid(), signalCode)
    }

    /// 同步上报崩溃（用于崩溃时立即上报）
    private func reportCrashSync(userInfo: [String: Any], deviceInfo: [String: Any], crashInfo: [String: Any]) {
        let target = AQAPIService.reportCrash(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo)
        let plugins = (target as? NetworkPluginProvider)?.plugins ?? []
        let provider = MoyaProvider<MultiTarget>(plugins: plugins)
        let semaphore = DispatchSemaphore(value: 0)

        var uploadSucceeded = false
        var failureReason: String?

        provider.request(MultiTarget(target)) { result in
            defer { semaphore.signal() }

            switch result {
            case let .success(response):
                if response.statusCode == 200 {
                    if let crashResponse = try? JSONDecoder().decode(CrashReportResponse.self, from: response.data) {
                        if crashResponse.code == 200 || crashResponse.data?.success == true {
                            uploadSucceeded = true
                        } else {
                            failureReason = crashResponse.msg ?? crashResponse.data?.message ?? "服务器返回错误"
                        }
                    } else {
                        uploadSucceeded = true
                    }
                } else {
                    failureReason = "HTTP \(response.statusCode)"
                }

            case let .failure(error):
                failureReason = error.localizedDescription
            }
        }

        let waitResult = semaphore.wait(timeout: .now() + 3)
        if waitResult == .timedOut {
            failureReason = "请求超时"
        }

        if uploadSucceeded {
            print("✅ CrashManager upload successful")
        } else {
            print("❌ CrashManager upload failed: \(failureReason ?? "未知错误")")
            saveCrashToLocal(userInfo: userInfo, deviceInfo: deviceInfo, crashInfo: crashInfo)
        }
    }

    /// 保存崩溃信息到本地
    private func saveCrashToLocal(userInfo: [String: Any], deviceInfo: [String: Any], crashInfo: [String: Any]) {
        let crashData: [String: Any] = [
            "user_info": userInfo,
            "device_info": deviceInfo,
            "crash_info": crashInfo,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: crashData, options: .prettyPrinted)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let crashLogsDir = documentsPath.appendingPathComponent("CrashLogs")

            // 创建目录
            try FileManager.default.createDirectory(at: crashLogsDir, withIntermediateDirectories: true)

            // 保存文件
            let filename = "crash_\(Date().timeIntervalSince1970).json"
            let fileURL = crashLogsDir.appendingPathComponent(filename)
            try jsonData.write(to: fileURL)

            print("💾 Crash saved to local: \(fileURL.path)")
        } catch {
            print("❌ Failed to save crash to local: \(error)")
        }
    }

    /// 安装信号处理器
    private func installSignalHandlers() {
        let signals = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP, SIGQUIT]

        for signal in signals {
            var action = sigaction()
            action.__sigaction_u.__sa_handler = { signal in
                CrashManager.shared.handleSignal(signal)
            }
            sigemptyset(&action.sa_mask)
            action.sa_flags = SA_RESETHAND | SA_NODEFER
            sigaction(signal, &action, nil)
        }
    }

    /// 获取信号名称
    private func getSignalName(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "UNKNOWN(\(signal))"
        }
    }

    /// 上传待处理的崩溃日志
    private func uploadPendingCrashLogs() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let crashLogsDir = documentsPath.appendingPathComponent("CrashLogs")

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

            // 异步上报
            uploadCrashDataAsync(crashData: crashInfo) { [weak self] success in
                if success {
                    // 上报成功，删除本地文件
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

            // 异步上报
            self.uploadCrashDataAsync(crashData: [
                "user_info": userInfo,
                "device_info": deviceInfo,
                "crash_info": crashInfo,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]) { success in
                if success {
                    print("✅ Custom crash report uploaded successfully")
                } else {
                    print("❌ Failed to upload custom crash report")
                }
            }
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
