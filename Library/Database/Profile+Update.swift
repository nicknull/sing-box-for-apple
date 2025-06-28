import Foundation
import GRDB
import Libbox

public extension Profile {
    nonisolated func updateRemoteProfile() async throws {
        if type != .remote {
            return
        }
//        guard let filePath = Bundle.main.path(forResource: "subscribe", ofType: "json") else {
//            print("文件未找到")
//            exit(1)
//        }

        let remoteContent = try HTTPClient().getString(remoteURL)
//        let remoteContent = try String(contentsOfFile: filePath, encoding: .utf8)

        var error: NSError?
        LibboxCheckConfig(remoteContent, &error)
        if let error {
            throw error
        }
        lastUpdated = Date()
        try await ProfileManager.update(self)
        do {
            let oldContent = try read()
            if oldContent == remoteContent {
                return
            }
        } catch {}
        try write(remoteContent)
        try await onProfileUpdated()
    }

    nonisolated func onProfileUpdated() async throws {
        if await SharedPreferences.selectedProfileID.get() == id {
            if let profile = try? await ExtensionProfile.load() {
                if profile.status == .connected {
                    try LibboxNewStandaloneCommandClient()!.serviceReload()
                }
            }
        }
    }
}
