//
//  SharedUserKit.swift
//  sing-box-for-apple
//
//  汇总用户领域的共享入口，方便跨目标导入核心类型与构建辅助方法。
//

import Foundation

enum SharedUserKit {
    /// 工厂方法：创建默认的用户管理器实例。
    @MainActor static func makeUserManager() -> UserManager {
        UserManager()
    }

    /// 工厂方法：创建默认的 OAuth 绑定管理器。
    static func makeOAuthBindingManager(
        googleClientID: String,
        githubClientID: String
    ) -> OAuthBindingManager {
        OAuthBindingManager(
            googleClientID: googleClientID,
            githubClientID: githubClientID
        )
    }
}
