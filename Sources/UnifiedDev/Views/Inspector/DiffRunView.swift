import SwiftUI
import Core

struct DiffRunLine: Equatable {
    var line: DiffLine?
    var carry: LexState = LexState()
    var emphasis: [Range<String.Index>] = []
    var isCommented: Bool = false
}

struct DiffRunView: View, Equatable {
    var lines: [DiffRunLine]
    var language: Language
    var numbers: DiffGutter.Numbers = .both
    var width: CGFloat
    var wrappedHeights: [CGFloat]?
    var lookupRevision = 0
    var onLookup: ((CodeTextView, Int, Bool, Bool, Bool) -> Void)?
    var destination: CodeLocation?
    var onComment: ((ReviewSpot) -> Void)?
    var onDragComment: ((ReviewSpot, ReviewSpot) -> Void)?
    var onEndCommentDrag: (() -> Void)?
    var onEdit: ((Int) -> Void)?

    @State private var hovered: Int?

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lines == rhs.lines
            && lhs.language == rhs.language
            && lhs.numbers == rhs.numbers
            && lhs.width == rhs.width
            && lhs.wrappedHeights == rhs.wrappedHeights
            && lhs.destination == rhs.destination
            && lhs.lookupRevision == rhs.lookupRevision
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let wrappedHeights {
                WrappedDiffChrome(
                    lines: lines, heights: wrappedHeights, numbers: numbers,
                    onComment: { index in
                        if let spot = spot(of: lines[index]) { onComment?(spot) }
                    },
                    onEdit: { index in
                        if let line = editableLine(of: lines[index]) { onEdit?(line) }
                    },
                    commentable: lines.map { spot(of: $0) != nil },
                    editable: lines.map { editableLine(of: $0) != nil }
                )
                .overlay(alignment: .topLeading) {
                    if let hovered, lines.indices.contains(hovered) {
                        commentButton(Row(id: hovered, entry: lines[hovered], isHovered: true))
                            .frame(height: CodeMetrics.rowHeight)
                            .offset(y: wrappedHeights.prefix(hovered).reduce(0, +))
                    }
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in chrome(row) }
                }
            }
            WrappedCodeText(
                lines: runLines, language: language,
                width: wrappedCodeWidth, heights: wrappedHeights ?? Array(repeating: CodeMetrics.rowHeight, count: lines.count),
                onComment: { index in
                    if let spot = spot(of: lines[index]) { onComment?(spot) }
                },
                onEdit: { index in
                    if let line = editableLine(of: lines[index]) { onEdit?(line) }
                },
                commentable: lines.map { spot(of: $0) != nil },
                editable: lines.map { editableLine(of: $0) != nil },
                wraps: wrappedHeights != nil,
                onLookup: onLookup,
                highlightedOffset: destinationOffset
            )
            .frame(width: wrappedCodeWidth, height: wrappedHeights?.reduce(0, +) ?? CodeMetrics.rowHeight * CGFloat(lines.count))
            .padding(.leading, columnsWidth)
            .accessibilityHidden(true)
        }
        .frame(width: width, height: wrappedHeights?.reduce(0, +) ?? CodeMetrics.rowHeight * CGFloat(lines.count), alignment: .topLeading)
        .contentShape(Rectangle())
        .overlay {
            DiffRowHover(rowHeight: CodeMetrics.rowHeight, rowCount: lines.count,
                         rowHeights: wrappedHeights) { hovered = $0 }
        }
    }

    private struct Row: Identifiable, Equatable {
        var id: Int
        var entry: DiffRunLine
        var isHovered: Bool
    }

    private var rows: [Row] {
        lines.indices.map { Row(id: $0, entry: lines[$0], isHovered: hovered == $0) }
    }

    private func chrome(_ row: Row) -> some View {
        let entry = row.entry
        return HStack(spacing: 0) {
            DiffGutter(line: entry.line, numbers: numbers)
            DiffMarker(line: entry.line)
            Spacer(minLength: 0)
        }
        .frame(height: CodeMetrics.rowHeight)
        .frame(width: width, height: wrappedHeights?[row.id] ?? CodeMetrics.rowHeight, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DiffGutter.speech(for: entry.line))
        .accessibilityHidden(entry.line == nil)
        .overlay(alignment: .topLeading) { commentButton(row).frame(height: CodeMetrics.rowHeight) }
        .contextMenu {
            if let spot = spot(of: entry) {
                Button("Comment on This Line") { onComment?(spot) }
            }
            if let line = editableLine(of: entry), let onEdit {
                Button("Edit These Lines") { onEdit(line) }
            }
        }
        .background(entry.isCommented ? Palette.reviewLine : .clear)
        .background(DiffWash.background(of: entry.line))
        .background(alignment: .trailing) {
            if entry.line == nil {
                Rectangle()
                    .fill(Palette.surfaceSunken)
                    .frame(width: max(0, width - DiffGutter.width(for: numbers)))
            }
        }
    }

    @ViewBuilder
    private func commentButton(_ row: Row) -> some View {
        if let onComment, let spot = spot(of: row.entry) {
            DiffCommentButton(
                spot: spot,
                isRowHovered: row.isHovered,
                onComment: onComment,
                onDrag: drag(from: spot, at: row.id),
                onDragEnd: onEndCommentDrag
            )
        }
    }

    private func drag(from spot: ReviewSpot, at index: Int) -> ((CGFloat) -> Void)? {
        guard let onDragComment else { return nil }
        return { travel in
            guard let target = DiffDragRange.spot(
                from: index,
                translation: travel,
                rowHeight: CodeMetrics.rowHeight,
                rowHeights: wrappedHeights,
                spots: dragSpots,
                side: spot.side
            ) else { return }
            onDragComment(spot, target)
        }
    }

    private var dragSpots: [ReviewSpot?] {
        lines.map { DiffCommentSpot.offered(for: $0.line, numbers: numbers, enabled: true) }
    }

    private var destinationOffset: Int? {
        guard let destination else { return nil }
        var offset = 0
        for entry in lines {
            if let line = entry.line, line.kind != .deletion, line.newNumber == destination.line {
                return offset + min(destination.column - 1, max(0, line.text.utf16.count - 1))
            }
            offset += (entry.line?.text.utf16.count ?? 0) + 1
        }
        return nil
    }

    private var wrappedCodeWidth: CGFloat {
        floor(max(1, width - columnsWidth - CodeMetrics.gutterPadding))
    }

    private var columnsWidth: CGFloat {
        DiffGutter.width(for: numbers) + CodeMetrics.markerWidth
    }

    private func spot(of entry: DiffRunLine) -> ReviewSpot? {
        DiffCommentSpot.offered(for: entry.line, numbers: numbers, enabled: onComment != nil)
    }

    private func editableLine(of entry: DiffRunLine) -> Int? {
        DiffEditTarget.offered(for: entry.line, numbers: numbers, enabled: onEdit != nil)
    }

    private var runLines: [CodeRunLine] {
        lines.map { entry in
            CodeRunLine(
                text: DiffLineDisplay.text(entry.line?.text ?? ""),
                carry: entry.carry,
                emphasis: entry.emphasis,
                emphasisColor: DiffWash.emphasis(of: entry.line)
            )
        }
    }
}
