import Foundation

public struct BrowserAddressDisplay: Equatable, Sendable {
    public var leading: String
    public var host: String
    public var trailing: String
    public var security: Security

    public var isEmpty: Bool { leading.isEmpty && host.isEmpty && trailing.isEmpty }

    public enum Security: Equatable, Sendable {
        case none
        case local
        case insecure
        case secure

        public var symbol: String? {
            switch self {
            case .none: nil
            case .local: "desktopcomputer"
            case .insecure: "globe"
            case .secure: "lock.fill"
            }
        }

        public var help: String? {
            switch self {
            case .none: nil
            case .local: "A server on this Mac"
            case .insecure: "This connection is not encrypted"
            case .secure: "This connection is encrypted"
            }
        }
    }

    public static let limit = 512

    public static func of(_ address: String) -> BrowserAddressDisplay {
        let text = sanitised(address)
        guard let parts = URLComponents(string: text),
              let host = parts.encodedHost, !host.isEmpty
        else {
            return BrowserAddressDisplay(leading: text, host: "", trailing: "", security: .none)
        }

        let scheme = parts.scheme?.lowercased()
        var leading = scheme.map { $0 + "://" } ?? ""
        if let user = parts.percentEncodedUser {
            let password = parts.percentEncodedPassword.map { ":" + $0 } ?? ""
            leading += user + password + "@"
        }

        var trailing = parts.percentEncodedPath
        if let query = parts.percentEncodedQuery { trailing += "?" + query }
        if let fragment = parts.percentEncodedFragment { trailing += "#" + fragment }

        let head = leading.count + host.count
        if head + trailing.count > limit {
            trailing = String(trailing.prefix(max(0, limit - head))) + "…"
        }

        return BrowserAddressDisplay(
            leading: leading,
            host: host + (parts.port.map { ":\($0)" } ?? ""),
            trailing: trailing,
            security: security(scheme: scheme, host: host)
        )
    }

    private static func security(scheme: String?, host: String) -> Security {
        switch scheme {
        case "https": .secure
        case "http": BrowserAddress.isLocal(host: host) ? .local : .insecure
        default: .none
        }
    }

    private static func sanitised(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0..<0x20, 0x7F, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069: false
            default: true
            }
        }
        let text = String(String.UnicodeScalarView(kept))
        return text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
