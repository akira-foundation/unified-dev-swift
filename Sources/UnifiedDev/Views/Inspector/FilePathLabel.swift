import SwiftUI
import Core

struct FilePathLabel: View {
    var path: String

    var width: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if let folder {
                folder
                    .font(Typo.body)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .layoutPriority(-1)
            }

            Text(filename)
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .help(path)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(path)
    }

    private var folder: Text? {
        let crumbs = FileBarLayout.crumbs(for: directory, width: width)
        guard !crumbs.isEmpty else { return nil }

        var runs = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        if crumbs.isElided {
            runs.appendInterpolation(Text(verbatim: "…").foregroundStyle(Palette.textTertiary))
            runs.appendInterpolation(separator)
        }
        for component in crumbs.components {
            runs.appendInterpolation(Text(component).foregroundStyle(Palette.textTertiary))
            runs.appendInterpolation(separator)
        }
        return Text(LocalizedStringKey(stringInterpolation: runs))
    }

    private var separator: Text {
        Text(verbatim: "/").foregroundStyle(Palette.textTertiary.opacity(0.5))
    }

    private var filename: String { (path as NSString).lastPathComponent }

    private var directory: String { (path as NSString).deletingLastPathComponent }
}
