import Foundation

public enum BrowserKeyPress: String, Sendable, Equatable, CaseIterable {
    case enter
    case tab
    case escape
    case backspace
    case up
    case down
    case left
    case right

    public static func parse(_ raw: String?) -> Result<BrowserKeyPress, PaneRefusal> {
        let offered = allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        let asked = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !asked.isEmpty else {
            return .failure(
                PaneRefusal("browser_press needs a 'key'. It sends \(offered).")
            )
        }
        guard let key = Self(rawValue: asked) else {
            return .failure(
                PaneRefusal(
                    "Unified Dev does not send '\(asked)'. 'key' takes \(offered), one at a time. "
                        + "There are no modifiers here: a shortcut of the person's own is theirs "
                        + "to press."
                )
            )
        }
        return .success(key)
    }
}

public enum BrowserWaitCondition: Sendable, Equatable {
    case text(String)
    case gone(String)
    case load

    public static func parse(
        text: String?, gone: String?
    ) -> Result<BrowserWaitCondition, PaneRefusal> {
        let wanted = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let unwanted = (gone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard wanted.isEmpty || unwanted.isEmpty else {
            return .failure(
                PaneRefusal(
                    "browser_wait waits for one thing at a time. Pass 'text' or 'gone', not both, "
                        + "and leave both out to wait for the load to finish."
                )
            )
        }
        guard wanted.isEmpty else { return .success(.text(wanted)) }
        guard unwanted.isEmpty else { return .success(.gone(unwanted)) }
        return .success(.load)
    }
}

public struct BrowserWaitSeconds: Sendable {
    public static let minimum = 1
    public static let maximum = 30
    public static let fallback = 10

    public static func parse(_ value: JSONValue?) -> Result<Int, PaneRefusal> {
        switch value {
        case .none, .null:
            return .success(fallback)
        case .integer(let seconds):
            return bounded(seconds)
        case .number(let seconds):
            return bounded(Int(seconds.rounded()))
        default:
            return .failure(
                PaneRefusal(
                    "'seconds' is a whole number of seconds, between \(minimum) and \(maximum). "
                        + "Leave it out to wait \(fallback)."
                )
            )
        }
    }

    private static func bounded(_ seconds: Int) -> Result<Int, PaneRefusal> {
        guard (minimum...maximum).contains(seconds) else {
            return .failure(
                PaneRefusal(
                    "browser_wait waits between \(minimum) and \(maximum) seconds, and \(seconds) "
                        + "is outside that. A page that takes longer than \(maximum) seconds is "
                        + "one to tell the person about rather than to sit on."
                )
            )
        }
        return .success(seconds)
    }
}
