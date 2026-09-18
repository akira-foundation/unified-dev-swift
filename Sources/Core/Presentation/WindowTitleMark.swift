import Foundation

public enum WindowTitleMark {
    public static let defaultTitle = "Unified Dev"

    public static var prefix: String {
        prefix(info: Bundle.main.infoDictionary)
    }

    public static func prefix(info: [String: Any]?) -> String {
        info?[PreviewIdentity.titlePrefixKey] as? String ?? ""
    }

    public static func decorate(_ title: String, prefix: String = Self.prefix) -> String {
        prefix + title
    }
}
