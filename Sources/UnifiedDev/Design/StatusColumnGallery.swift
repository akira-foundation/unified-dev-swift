import SwiftUI
import Core

struct StatusColumnGallery: View {
    private static let states = WorkspaceStatus.allCases

    private static let magnification: CGFloat = 6

    private static var rows: [[WorkspaceStatus]] {
        stride(from: 0, to: states.count, by: 5).map {
            Array(states[$0..<min($0 + 5, states.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status column")
                    .font(Typo.title)
                Text("Every mark the column can draw, in the sidebar's own layout and at its own width.")
                    .font(Typo.label)
                    .foregroundStyle(Palette.textSecondary)
                Text("Held still. \"Agent running\" is the real mark at rest, which is what Reduce Motion draws; \"Setting up\" is a stand-in for a spinner no offscreen render can photograph.")
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }

            HStack(alignment: .top, spacing: Metrics.gutter) {
                column("On the sidebar's own ground", onSelection: false, background: Palette.controlStrip)
                column(
                    "On a selected row",
                    onSelection: true,
                    background: Palette.selectedEmphasized
                )
            }

            boxes
        }
        .padding(Metrics.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.surface)
    }

    private func column(_ title: String, onSelection: Bool, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)

            VStack(spacing: 0) {
                ForEach(Self.states, id: \.self) { row($0, onSelection: onSelection) }
            }
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func row(_ status: WorkspaceStatus, onSelection: Bool) -> some View {
        Label {
            Text(status.label)
                .foregroundStyle(
                    onSelection ? Palette.selectedEmphasizedText : Palette.textPrimary
                )
        } icon: {
            mark(status, onSelection: onSelection)
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.rowIndent)
        .frame(width: Metrics.sidebarWidth, height: 32, alignment: .leading)
    }

    private var boxes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Each mark on its box, at six times")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            Text("Outer square: the \(Self.number(Metrics.glyph)) point box every mark is framed in. Inner circle: the \(Self.number(Metrics.glyphInk)) points of ink a round symbol in it draws.")
                .font(Typo.micro)
                .foregroundStyle(Palette.textTertiary)

            ForEach(Self.rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: Metrics.gutter) {
                    ForEach(Self.rows[index], id: \.self) { enlarged($0) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func enlarged(_ status: WorkspaceStatus) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .strokeBorder(Palette.border, lineWidth: Metrics.hairline / Self.magnification)
                Circle()
                    .strokeBorder(
                        Palette.accent.opacity(0.4),
                        style: StrokeStyle(
                            lineWidth: Metrics.hairline / Self.magnification,
                            dash: [1, 1]
                        )
                    )
                    .frame(width: Metrics.glyphInk, height: Metrics.glyphInk)
                mark(status, onSelection: false)
            }
            .frame(width: Metrics.glyph, height: Metrics.glyph)
            .scaleEffect(Self.magnification, anchor: .center)
            .frame(
                width: Metrics.glyph * Self.magnification,
                height: Metrics.glyph * Self.magnification
            )
            .background(Palette.surfaceSunken)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(status.label)
                .font(Typo.micro)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.glyph * Self.magnification)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func mark(_ status: WorkspaceStatus, onSelection: Bool) -> some View {
        if status == .settingUp {
            SettingUpStill()
        } else {
            WorkspaceStatusGlyph(status: status, isOnSelection: onSelection)
        }
    }

    private static func number(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(Double(value))
    }
}

private struct SettingUpStill: View {
    private static let indicator: CGFloat = 10
    private static let spokes = 8

    var body: some View {
        ZStack {
            ForEach(0..<Self.spokes, id: \.self) { spoke in
                Capsule()
                    .fill(Palette.textTertiary)
                    .frame(width: Self.indicator / 8, height: Self.indicator / 3)
                    .offset(y: -(Self.indicator - Self.indicator / 3) / 2)
                    .rotationEffect(.degrees(Double(spoke) / Double(Self.spokes) * 360))
            }
        }
        .frame(width: Metrics.glyph, height: Metrics.glyph)
    }
}

extension Gallery {
    static let statusColumn = Gallery(
        name: "status-column",
        title: "Status column",
        size: CGSize(width: 640, height: 1080),
        needsFocus: false,
        view: { _ in AnyView(StatusColumnGallery()) }
    )
}
