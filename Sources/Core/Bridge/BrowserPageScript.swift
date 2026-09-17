import Foundation

public enum BrowserPageScript: Sendable, Equatable {
    case visibleText

    case scroll(BrowserScroll)

    public var source: String {
        switch self {
        case .visibleText:
            return """
                (function () {
                  var body = document.body;
                  return body ? body.innerText : "";
                })()
                """
        case .scroll(let scroll):
            return """
                (function () {
                  \(scroll.movement)
                  var page = document.documentElement || {};
                  return [
                    Math.round(window.scrollY || 0),
                    Math.round(page.scrollHeight || 0),
                    Math.round(window.innerHeight || 0)
                  ];
                })()
                """
        }
    }
}

public struct BrowserScroll: Sendable, Equatable {
    public enum Direction: String, Sendable, Equatable, CaseIterable {
        case down
        case up
        case top
        case bottom

        var takesDistance: Bool { self == .down || self == .up }
    }

    public var direction: Direction

    public var percent: Int

    public static let defaultPercent = 100
    public static let minimumPercent = 10
    public static let maximumPercent = 2_000

    public init(direction: Direction, percent: Int = BrowserScroll.defaultPercent) {
        self.direction = direction
        self.percent = percent
    }

    var movement: String {
        switch direction {
        case .down: "window.scrollBy(0, Math.round(window.innerHeight * \(percent) / 100));"
        case .up: "window.scrollBy(0, -Math.round(window.innerHeight * \(percent) / 100));"
        case .top: "window.scrollTo(0, 0);"
        case .bottom:
            "window.scrollTo(0, (document.documentElement || {}).scrollHeight || 0);"
        }
    }

    public static func parse(direction rawDirection: String?, pages rawPages: JSONValue?)
        -> Result<BrowserScroll, PaneRefusal> {
        let list = Direction.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
        let raw = rawDirection?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !raw.isEmpty else {
            return .failure(
                PaneRefusal("browser_scroll needs a 'direction'. It takes \(list).")
            )
        }
        guard let direction = Direction(rawValue: raw) else {
            return .failure(
                PaneRefusal("Unified Dev does not scroll '\(raw)'. 'direction' takes \(list).")
            )
        }

        switch rawPages {
        case .none, .null:
            return .success(BrowserScroll(direction: direction))
        default:
            guard direction.takesDistance else {
                return .failure(
                    PaneRefusal(
                        "'pages' means nothing with direction '\(raw)', which goes to the end of "
                            + "the page. Drop it, or scroll 'up' or 'down' by that much."
                    )
                )
            }
            guard let pages = number(rawPages) else {
                return .failure(
                    PaneRefusal(
                        "'pages' is how many screenfuls to scroll, as a number. Leave it out for "
                            + "one screenful."
                    )
                )
            }
            let percent = Int((pages * 100).rounded())
            guard percent >= minimumPercent, percent <= maximumPercent else {
                return .failure(
                    PaneRefusal(
                        "'pages' is between \(fraction(minimumPercent)) and "
                            + "\(fraction(maximumPercent)) screenfuls. For the whole page use "
                            + "direction 'top' or 'bottom'."
                    )
                )
            }
            return .success(BrowserScroll(direction: direction, percent: percent))
        }
    }

    private static func number(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let double): double
        case .integer(let integer): Double(integer)
        default: nil
        }
    }

    private static func fraction(_ percent: Int) -> String {
        let pages = Double(percent) / 100
        return pages == pages.rounded() ? String(Int(pages)) : String(pages)
    }

    public func report(offset: Int, height: Int, viewport: Int) -> String {
        let moved: String
        switch direction {
        case .down, .up: moved = "Scrolled \(direction.rawValue) \(fraction)."
        case .top: moved = "Scrolled to the top of the page."
        case .bottom: moved = "Scrolled to the bottom of the page."
        }
        guard height > 0 else { return moved }
        let atBottom = offset + viewport >= height - 2
        let position = atBottom
            ? "The view is at the bottom of a \(height) pixel page."
            : "The view starts \(offset) pixels into a \(height) pixel page and shows \(viewport) "
                + "of them."
        return "\(moved) \(position)"
    }

    private var fraction: String {
        percent == 100 ? "one screen" : "\(Self.fraction(percent)) screens"
    }
}

public enum BrowserPageText {
    public static let limit = 20_000

    public static func trim(_ text: String) -> (text: String, cut: Bool) {
        guard text.count > limit else { return (text, false) }
        return (String(text.prefix(limit)), true)
    }
}
