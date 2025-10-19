//
//  MonitoringNetworkState.swift
//  sing-box
//
//  Created by xiaokang chen on 2024/9/5.
//

import Foundation
import Network

class MonitoringNetworkState: ObservableObject {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    @Published var isConnected = false
    private var lastStatus: NWPath.Status?

    init() {
        monitor.start(queue: queue)

        monitor.pathUpdateHandler = { path in
            let satisfied = (path.status == .satisfied)
            DispatchQueue.main.async {
                if satisfied {
                    if self.lastStatus != .satisfied {
                        NotificationCenter.default.post(name: .networkBecameReachable, object: nil)
                    }
                    self.isConnected = true
                } else {
                    self.isConnected = false
                }
                self.lastStatus = path.status
            }
        }
    }
}

extension Notification.Name {
    static let networkBecameReachable = Notification.Name("networkBecameReachableNotification")
}
