import Foundation

public enum PaneCloseTarget: Sendable, Equatable {
    case focused
    case pane(PaneKind)
    case canvas

    public static let canvasWord = "canvas"

    public static var words: [String] { PaneKind.allCases.map(\.rawValue) + [canvasWord] }

    public static var kindList: String { words.map { "'\($0)'" }.joined(separator: ", ") }

    public static func parse(_ raw: String?) -> Result<PaneCloseTarget, PaneRefusal> {
        guard let word = raw?.trimmingCharacters(in: .whitespaces), !word.isEmpty else { return .success(.focused) }
        if word == canvasWord { return .success(.canvas) }
        guard let kind = PaneKind(rawValue: word) else {
            return .failure(PaneRefusal("Unified Dev has no pane called '\(word)'. It closes \(kindList)."))
        }
        return .success(.pane(kind))
    }
}
