import Foundation

public enum OpenURLArgument {
    public static func url(from argument: String) -> URL? {
        if let direct = URL(string: argument), let scheme = direct.scheme, !scheme.isEmpty {
            return direct
        }
        return repaired(argument)
    }

    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func repaired(_ argument: String) -> URL? {
        guard let separator = argument.range(of: "://") else { return nil }

        let scheme = String(argument[..<separator.lowerBound])
        let validScheme = !scheme.isEmpty
            && scheme.first?.isLetter == true
            && scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
        guard validScheme else { return nil }

        let payload = argument[separator.upperBound...]
            .split(separator: "&", omittingEmptySubsequences: false)
            .map { pair in
                pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    .map { piece in
                        String(piece).addingPercentEncoding(withAllowedCharacters: unreserved)
                            ?? String(piece)
                    }
                    .joined(separator: "=")
            }
            .joined(separator: "&")

        return URL(string: scheme + "://" + payload)
    }
}
