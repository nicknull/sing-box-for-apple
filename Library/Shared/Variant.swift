import Foundation

public enum Variant {
    #if os(macOS)
        public static var useSystemExtension = false
    #else
        public static let useSystemExtension = false
    #endif

    #if os(iOS)
        public static let applicationName = "iFlash"
    #elseif os(macOS)
        public static let applicationName = "iFlash"
    #elseif os(tvOS)
        public static let applicationName = "iFlash"
    #endif
}
