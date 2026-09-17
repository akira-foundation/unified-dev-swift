import SwiftUI
import Core

struct DiffRunGallery: View {
    let app: AppModel

    private static let width: CGFloat = 620

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            case_(
                "A run, and the rows it replaces",
                "The same six lines twice. The gutters have to be the same gutter: a diff draws "
                    + "both kinds at once, wherever a comment band or an expander stops a run."
            ) {
                ruled(count: Self.lines.count) {
                    DiffRunView(lines: Self.run, language: .swift, width: Self.width)
                }
                Hairline()
                ruled(count: Self.lines.count) {
                    VStack(spacing: 0) {
                        ForEach(Self.lines, id: \.index) { line in
                            DiffLineView(
                                line: line,
                                language: .swift,
                                emphasis: Self.emphasis(of: line),
                                width: Self.width
                            )
                        }
                    }
                }
            }

            case_(
                "Forty lines, which is where drift would show",
                "A fraction of a point per line is invisible on six and half a row on forty."
            ) {
                ruled(count: 40) {
                    DiffRunView(lines: Self.long, language: .swift, width: Self.width)
                }
            }

            case_(
                "Nothing opposite it",
                "The side by side padding starts at the marker column, not at the row's edge, so "
                    + "the numbers keep the pane's own ground the way the per line rows leave them."
            ) {
                ruled(count: Self.opposite.count) {
                    DiffRunView(
                        lines: Self.opposite,
                        language: .swift,
                        numbers: .old,
                        width: Self.width / 2
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func ruled(count: Int, @ViewBuilder content: () -> some View) -> some View {
        content()
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { _ in
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Palette.controlAccent.opacity(0.35))
                                .frame(height: Metrics.hairline)
                            Spacer(minLength: 0)
                        }
                        .frame(height: CodeMetrics.rowHeight)
                    }
                }
                .allowsHitTesting(false)
            }
    }

    private func case_(
        _ title: String, _ note: String, @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typo.label).foregroundStyle(Palette.textSecondary)
            Text(note)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                content()
            }
            .background(Palette.surface)
        }
    }

    private static let lines: [DiffLine] = [
        DiffLine(
            kind: .context, text: "func render(_ document: DiffDocument) -> some View {",
            oldNumber: 12, newNumber: 12, index: 0
        ),
        DiffLine(
            kind: .deletion, text: "    let width = proxy.size.width",
            oldNumber: 13, index: 1
        ),
        DiffLine(
            kind: .addition, text: "    let width = max(proxy.size.width, intrinsic(document))",
            newNumber: 13, index: 2
        ),
        DiffLine(
            kind: .context, text: "    return ScrollView([.vertical, .horizontal]) {",
            oldNumber: 14, newNumber: 14, index: 3
        ),
        DiffLine(
            kind: .context, text: "        LazyVStack(alignment: .leading, spacing: 0) { rows }",
            oldNumber: 15, newNumber: 15, index: 4
        ),
        DiffLine(kind: .context, text: "    }", oldNumber: 16, newNumber: 16, index: 5),
    ]

    static func emphasis(of line: DiffLine) -> [Range<String.Index>] {
        guard let found = line.text.range(of: line.kind == .addition ? "max(" : "proxy.size.width")
        else { return [] }
        return [found]
    }

    private static let run: [DiffRunLine] = lines.map {
        DiffRunLine(line: $0, emphasis: emphasis(of: $0), isCommented: $0.index == 4)
    }

    private static let long: [DiffRunLine] = (0..<40).map { offset in
        DiffRunLine(
            line: DiffLine(
                kind: offset % 7 == 0 ? .addition : .context,
                text: "    let value\(offset) = compute(input: \(offset))",
                oldNumber: 100 + offset,
                newNumber: 100 + offset,
                index: 100 + offset
            )
        )
    }

    private static let opposite: [DiffRunLine] = [
        DiffRunLine(
            line: DiffLine(
                kind: .deletion, text: "    let stale = true", oldNumber: 41, index: 200
            )
        ),
        DiffRunLine(line: nil),
        DiffRunLine(line: nil),
        DiffRunLine(
            line: DiffLine(
                kind: .context, text: "    return stale", oldNumber: 42, newNumber: 40, index: 203
            )
        ),
    ]
}

extension Gallery {
    static let diffRun = Gallery(
        name: "diff-run",
        title: "Diff runs and the rule they sit on",
        size: CGSize(width: 700, height: 1_220),
        needsFocus: false,
        view: { app in AnyView(DiffRunGallery(app: app)) }
    )
}
