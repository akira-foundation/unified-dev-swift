import Foundation

public struct MarkdownSelectedPiece: Sendable, Equatable {
    public var index: Int
    public var includesMarker: Bool
    public var text: String

    public init(index: Int, includesMarker: Bool, text: String) {
        self.index = index
        self.includesMarker = includesMarker
        self.text = text
    }
}

public enum MarkdownSelectionCopy {
    public static let softBreak = "\u{2028}"

    public static func text(of selected: [MarkdownSelectedPiece], in pieces: [MarkdownPiece]) -> String {
        var output = ""
        var previous: MarkdownPiece?
        for part in selected where pieces.indices.contains(part.index) {
            let piece = pieces[part.index]
            if case .rule = piece.body { continue }
            if let previous { output += separator(between: previous, and: piece) }
            output += written(part, piece: piece, isFirst: previous == nil)
            previous = piece
        }
        return output
    }

    private static func separator(between previous: MarkdownPiece, and piece: MarkdownPiece) -> String {
        if case let .cell(cell) = piece.body, case let .cell(before) = previous.body, cell.table == before.table {
            return cell.row == before.row ? "\t" : "\n"
        }
        let staysInList = piece.listDepth > 0 && previous.listDepth > 0 && previous.root == piece.root
        return staysInList && piece.isTight ? "\n" : "\n\n"
    }

    private static func written(_ part: MarkdownSelectedPiece, piece: MarkdownPiece, isFirst: Bool) -> String {
        let text = part.text.replacingOccurrences(of: softBreak, with: "\n")
        let depth = piece.listDepth
        guard depth > 0 else { return text }
        let outer = String(repeating: "  ", count: depth - 1)
        let inner = outer + "  "
        if part.includesMarker, let marker = piece.marker {
            return outer + marker.written + " " + indented(text, by: inner, includingFirst: false)
        }
        if case let .cell(cell) = piece.body, cell.column > 0 { return text }
        if isFirst { return text }
        return indented(text, by: inner, includingFirst: true)
    }

    private static func indented(_ text: String, by indent: String, includingFirst: Bool) -> String {
        text.components(separatedBy: "\n").enumerated().map { offset, line in
            line.isEmpty || (offset == 0 && !includingFirst) ? line : indent + line
        }.joined(separator: "\n")
    }
}
