import AppKit
import Core

extension NSAttributedString.Key {
    static let markdownPiece = NSAttributedString.Key("unifieddev.markdown.piece")
    static let markdownMarker = NSAttributedString.Key("unifieddev.markdown.marker")
}

struct MarkdownTextStyle: Hashable {
    var scale: CGFloat
    var face: ChatFont
    var lineHeight: ChatLineHeight
    var ambientLeading: CGFloat
}

@MainActor
extension MarkdownTextStyle {
    var leading: CGFloat {
        if ambientLeading > 0 { return ambientLeading }
        return TranscriptLayout.proseLeading(Typo.body, scale: scale, face: face, lineHeight: lineHeight)
    }

    var taskLeading: CGFloat {
        TranscriptLayout.proseLeading(Typo.body, scale: scale, face: face, ratio: lineHeight.listRatio)
    }

    func points(for gap: MarkdownPiece.Gap) -> CGFloat {
        switch gap {
        case .none: 0
        case .block: MarkdownMetrics.blockGap
        case .heading: MarkdownMetrics.blockGap + MarkdownMetrics.headingLead
        case .tightItem: itemGap(tight: true, prose: true)
        case .looseItem: itemGap(tight: false, prose: true)
        case .task: itemGap(tight: true, prose: false)
        }
    }

    private func itemGap(tight: Bool, prose: Bool) -> CGFloat {
        TranscriptLayout.listItemGap(
            Typo.body, scale: scale, face: face, lineHeight: lineHeight, tight: tight, prose: prose
        )
    }
}

struct MarkdownCodeSpec {
    var index: Int
    var piece: Int
    var block: NSTextBlock
    var range: NSRange
    var code: String
    var language: Language
    var info: String
    var lines: Int
    var isFolded: Bool
    var visibleAll: Bool
    var footer: CGFloat
}

struct MarkdownQuoteSpec {
    var block: NSTextBlock
    var range: NSRange
    var depth: Int
}

struct MarkdownCellSpec {
    var block: NSTextBlock
    var location: Int
}

struct MarkdownTableSpec {
    var first: MarkdownCellSpec
    var firstRowLast: MarkdownCellSpec
    var last: MarkdownCellSpec
}

final class MarkdownText {
    let attributed: NSAttributedString
    let style: MarkdownTextStyle
    let isStreamingText: Bool
    let pieces: [MarkdownPiece]
    let rootStarts: [Int: Int]
    let code: [MarkdownCodeSpec]
    let quotes: [MarkdownQuoteSpec]
    let tables: [MarkdownTableSpec]
    let rules: [NSRange]

    init(
        attributed: NSAttributedString,
        style: MarkdownTextStyle,
        isStreamingText: Bool,
        pieces: [MarkdownPiece],
        rootStarts: [Int: Int],
        code: [MarkdownCodeSpec],
        quotes: [MarkdownQuoteSpec],
        tables: [MarkdownTableSpec],
        rules: [NSRange]
    ) {
        self.attributed = attributed
        self.style = style
        self.isStreamingText = isStreamingText
        self.pieces = pieces
        self.rootStarts = rootStarts
        self.code = code
        self.quotes = quotes
        self.tables = tables
        self.rules = rules
    }

    func keptPrefix(for new: [MarkdownPiece]) -> (pieces: Int, boundary: Int, length: Int)? {
        var same = 0
        while same < new.count, same < pieces.count, new[same] == pieces[same] { same += 1 }
        guard same > 0 else { return nil }
        let boundary = same < new.count ? new[same].root : (new.last?.root ?? 0) + 1
        let kept = new.prefix { $0.root < boundary }.count
        guard kept > 0 else { return nil }
        let length = kept < pieces.count ? rootStarts[pieces[kept].root] ?? attributed.length : attributed.length
        return length > 0 ? (kept, boundary, length) : nil
    }

    @MainActor
    func selectedText(in storage: NSAttributedString, ranges: [NSRange]) -> String {
        ranges.map { selectedText(in: storage, range: $0) }.joined(separator: "\n")
    }

    @MainActor
    private func selectedText(in storage: NSAttributedString, range: NSRange) -> String {
        var selected: [MarkdownSelectedPiece] = []
        storage.enumerateAttributes(in: range) { attributes, run, _ in
            guard let index = attributes[.markdownPiece] as? Int else { return }
            if selected.last?.index != index {
                selected.append(MarkdownSelectedPiece(index: index, includesMarker: false, text: ""))
            }
            if attributes[.markdownMarker] != nil {
                selected[selected.count - 1].includesMarker = true
            } else {
                selected[selected.count - 1].text += TranscriptLink.selectedText(in: storage, range: run)
            }
        }
        return MarkdownSelectionCopy.text(of: selected, in: pieces)
    }
}
