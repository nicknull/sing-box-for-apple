import Foundation

public enum TestEnv {
    // 是否启用测试环境（启用后：host 固定，不被 Sync 覆盖）
    public static let isEnabled: Bool = true

    // 固定的测试环境 Host（需要时可修改为你的测试地址）
    public static let fixedHost: String = "http://test.erewwd.shop/"
}

