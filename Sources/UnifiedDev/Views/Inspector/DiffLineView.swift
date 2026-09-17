import SwiftUI
import Core

struct DiffLineView: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.line == rhs.line
            && lhs.language == rhs.language
            && lhs.carry == rhs.carry
            && lhs.emphasis == rhs.emphasis
            && lhs.numbers == rhs.numbers
            && lhs.width == rhs.width
            && lhs.isCommented == rhs.isCommented
    }

    typealias Numbers = DiffGutter.Numbers

    var line: DiffLine?
    var language: Language
    var carry: LexState = LexState()
    var emphasis: [Range<String.Index>] = []
    var numbers: Numbers = .both
    var width: CGFloat
    var isCommented: Bool = false
    var onComment: ((ReviewSpot) -> Void)?
    var onDragComment: ((ReviewSpot, ReviewSpot) -> Void)?
    var onEndCommentDrag: (() -> Void)?
    var onEdit: ((Int) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            DiffGutter(line: line, numbers: numbers)
            content
        }
        .frame(width: width, height: CodeMetrics.rowHeight, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DiffGutter.speech(for: line))
        .accessibilityHidden(line == nil)
        .overlay(alignment: .leading) { commentButton }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .background(isCommented ? Palette.reviewLine : .clear)
        .background(DiffWash.background(of: line))
        .contextMenu {
            if let spot = offeredSpot {
                Button("Comment on This Line") { onComment?(spot) }
            }
            if let line = editableLine, let onEdit {
                Button("Edit These Lines") { onEdit(line) }
            }
        }
    }

    private var offeredSpot: ReviewSpot? {
        DiffCommentSpot.offered(for: line, numbers: numbers, enabled: onComment != nil)
    }

    private var editableLine: Int? {
        DiffEditTarget.offered(for: line, numbers: numbers, enabled: onEdit != nil)
    }

    @ViewBuilder
    private var commentButton: some View {
        if let spot = offeredSpot, let onComment {
            DiffCommentButton(
                spot: spot,
                isRowHovered: isHovered,
                onComment: onComment,
                onDrag: drag(from: spot),
                onDragEnd: onEndCommentDrag
            )
        }
    }

    private func drag(from spot: ReviewSpot) -> ((CGFloat) -> Void)? {
        guard let onDragComment else { return nil }
        return { _ in onDragComment(spot, spot) }
    }

    @ViewBuilder
    private var content: some View {
        if let line {
            switch line.kind {
            case .noNewline:
                HStack(spacing: 0) {
                    DiffMarker(line: line)
                    Text("No newline at end of file")
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textTertiary)
                        .italic()
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                HStack(spacing: 0) {
                    DiffMarker(line: line)
                    CodeText(line: DiffLineDisplay.text(line.text), language: language, carry: carry)
                        .emphasizing(emphasis, color: DiffWash.emphasis(of: line))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Rectangle()
                .fill(Palette.surfaceSunken)
                .frame(maxWidth: .infinity)
        }
    }
}

enum DiffWash {
    static func background(of line: DiffLine?) -> Color {
        switch line?.kind {
        case .addition: Palette.diffAddBackground
        case .deletion: Palette.diffDeleteBackground
        default: .clear
        }
    }

    static func emphasis(of line: DiffLine?) -> Color {
        switch line?.kind {
        case .addition: Palette.diffAddEmphasis
        case .deletion: Palette.diffDeleteEmphasis
        default: .clear
        }
    }
}
