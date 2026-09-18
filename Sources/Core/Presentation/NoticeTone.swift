import Foundation

public enum NoticeTone: String, CaseIterable, Sendable, Hashable {
    case information
    case warning
    case error

    public enum Ink: Equatable, Sendable {
        case accent(beside: [PaletteMeaning])
        case meaning(PaletteMeaning)
    }

    public static let meaningsBesideAccent: [PaletteMeaning] = [.warning, .negative]

    public var symbol: String {
        switch self {
        case .information: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    public var ink: Ink {
        switch self {
        case .information: .accent(beside: Self.meaningsBesideAccent)
        case .warning: .meaning(.warning)
        case .error: .meaning(.negative)
        }
    }

    public var spokenName: String? {
        switch self {
        case .information: nil
        case .warning: "Warning"
        case .error: "Error"
        }
    }

    public func spoken(_ sentences: String...) -> String {
        let said = sentences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return ([spokenName].compactMap { $0 } + said).joined(separator: ". ")
    }

    public var next: NoticeTone {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? all.startIndex
        return all[(index + 1) % all.count]
    }
}
