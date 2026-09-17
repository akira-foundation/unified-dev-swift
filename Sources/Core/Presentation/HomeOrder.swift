import Foundation

public enum HomeOrder: String, Hashable, Sendable, CaseIterable, Codable {
    case recent
    case largest

    public var label: String {
        switch self {
        case .recent: "Recent"
        case .largest: "Largest"
        }
    }

    public var heading: String? {
        self == .largest ? "Largest first" : nil
    }

    public static func applies(scope: HomeScope, searching: Bool) -> Bool {
        !searching && scope.showsFootprints
    }
}
