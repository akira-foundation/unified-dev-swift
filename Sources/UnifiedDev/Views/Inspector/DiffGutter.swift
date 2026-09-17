import SwiftUI
import Core

struct DiffGutter: View {
    enum Numbers {
        case both
        case old
        case new
    }

    var line: DiffLine?
    var numbers: Numbers

    var body: some View {
        HStack(spacing: 0) {
            switch numbers {
            case .both:
                number(line?.oldNumber)
                number(line?.newNumber)
            case .old:
                number(line?.oldNumber)
            case .new:
                number(line?.newNumber)
            }
        }
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .font(Typo.codeTiny)
            .monospacedDigit()
            .foregroundStyle(Palette.textTertiary)
            .frame(width: CodeMetrics.numberWidth, alignment: .trailing)
            .padding(.trailing, CodeMetrics.gutterPadding)
    }

    static func width(for numbers: Numbers) -> CGFloat {
        let cell = CodeMetrics.numberWidth + CodeMetrics.gutterPadding
        return numbers == .both ? cell * 2 : cell
    }

    static func speech(for line: DiffLine?) -> String {
        guard let line else { return "" }
        if line.kind == .noNewline { return "No newline at end of file" }

        let number = line.newNumber ?? line.oldNumber
        let place = number.map { " \($0)" } ?? ""
        let state = switch line.kind {
        case .addition: "Added line\(place)"
        case .deletion: "Removed line\(place)"
        default: "Line\(place)"
        }

        let text = line.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "\(state), empty" : "\(state), \(text)"
    }
}

struct DiffMarker: View {
    var line: DiffLine?

    var body: some View {
        Text(text)
            .font(Typo.codeTiny)
            .foregroundStyle(Palette.textTertiary)
            .frame(width: CodeMetrics.markerWidth, alignment: .center)
    }

    private var text: String {
        switch line?.kind {
        case .addition: "+"
        case .deletion: "-"
        case .noNewline: "\\"
        default: " "
        }
    }
}

struct DiffCommentButton: View {
    static let dragThreshold: CGFloat = 4

    var spot: ReviewSpot
    var isRowHovered: Bool
    var onComment: (ReviewSpot) -> Void
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isDragging = false

    var body: some View {
        let shown = isRowHovered || isFocused || isDragging
        Button {
            onComment(spot)
        } label: {
            Image(systemName: "plus")
                .font(Typo.micro)
                .fontWeight(.bold)
                .foregroundStyle(shown ? Palette.selectedEmphasizedText : .clear)
                .frame(width: 16, height: 16)
                .background(
                    shown ? Palette.controlAccent : .clear,
                    in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .modifier(DiffCommentDrag(onDrag: onDrag, onDragEnd: onDragEnd, isDragging: $isDragging))
        .padding(.leading, Metrics.spacingTight)
        .help(onDrag == nil ? "Comment on this line" : "Comment on this line, or drag over several")
        .accessibilityLabel("Comment on line \(spot.line)")
    }
}

private struct DiffCommentDrag: ViewModifier {
    var onDrag: ((CGFloat) -> Void)?
    var onDragEnd: (() -> Void)?
    @Binding var isDragging: Bool

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: DiffCommentButton.dragThreshold)
                .onChanged { value in
                    guard let onDrag else { return }
                    isDragging = true
                    onDrag(value.translation.height)
                }
                .onEnded { _ in
                    guard onDrag != nil else { return }
                    isDragging = false
                    onDragEnd?()
                }
        )
    }
}

enum DiffEditTarget {
    static func offered(
        for line: DiffLine?,
        numbers: DiffGutter.Numbers,
        enabled: Bool
    ) -> Int? {
        guard enabled, numbers != .old, let spot = line?.reviewSpot, spot.side == .new else {
            return nil
        }
        return spot.line
    }
}

enum DiffCommentSpot {
    static func offered(
        for line: DiffLine?,
        numbers: DiffGutter.Numbers,
        enabled: Bool
    ) -> ReviewSpot? {
        guard enabled, let spot = line?.reviewSpot else { return nil }
        switch numbers {
        case .both: return spot
        case .old: return spot.side == .old ? spot : nil
        case .new: return spot.side == .new ? spot : nil
        }
    }
}
