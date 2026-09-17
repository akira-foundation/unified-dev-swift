import Foundation

public enum TreeDisclosureMotion: Equatable, Sendable {
    case instant
    case animated(seconds: Double)

    public var seconds: Double? {
        switch self {
        case .instant: nil
        case .animated(let seconds): seconds
        }
    }

    public static let rowLimit = 40

    public static func rows(changing count: Int, reduceMotion: Bool) -> TreeDisclosureMotion {
        guard count > 0, count <= rowLimit else { return .instant }
        return chevron(reduceMotion: reduceMotion)
    }

    public static func chevron(reduceMotion: Bool) -> TreeDisclosureMotion {
        guard let seconds = TranscriptMotion.disclosure(reduceMotion: reduceMotion) else {
            return .instant
        }
        return .animated(seconds: seconds)
    }
}
