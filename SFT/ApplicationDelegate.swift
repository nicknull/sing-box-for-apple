import ApplicationLibrary
import Foundation
import Libbox
import Library
import UIKit
import FirebaseCore

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        LibboxSetup(FilePath.sharedDirectory.relativePath, FilePath.workingDirectory.relativePath, FilePath.cacheDirectory.relativePath, true)
        setup()
        return true
    }

    private func setup() {
        do {
            try UIProfileUpdateTask.configure()
            NSLog("setup background task success")
        } catch {
            NSLog("setup background task error: \(error.localizedDescription)")
        }
    }
}
