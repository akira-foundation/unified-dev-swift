import SwiftUI
import Core

struct WorkspaceStatusGlyph: View {
    var status: WorkspaceStatus
    var isOnSelection = false

    var body: some View {
        content
            .frame(width: Metrics.glyph, height: Metrics.glyph)
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .settingUp:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
        case .running:
            WorkspaceRunningGlyph(isOnSelection: isOnSelection)
        default:
            Image(systemName: Self.symbol(for: status))
                .font(status == .unread ? Typo.micro : Typo.caption)
                .fontWeight(.semibold)
                .imageScale(.medium)
                .foregroundStyle(
                    isOnSelection ? AnyShapeStyle(Palette.textInverted) : Self.tint(for: status)
                )
        }
    }

    static func symbol(for status: WorkspaceStatus) -> String {
        switch status {
        case .settingUp, .running: ""
        case .awaitingPermission: "questionmark.circle.fill"
        case .setupFailed: "exclamationmark.triangle.fill"
        case .unread: "circle.fill"
        case .merged: "arrow.triangle.merge"
        case .closed: "slash.circle"
        case .conflicted: "exclamationmark.octagon.fill"
        case .checksFailing: "xmark.circle.fill"
        case .checksRunning: "clock"
        case .checksPassed: "checkmark.circle.fill"
        case .draft: "pencil"
        case .pullRequestOpen: "arrow.triangle.pull"
        case .changed: "arrow.triangle.branch"
        case .clean: "circle.dotted"
        }
    }

    static func tint(for status: WorkspaceStatus) -> AnyShapeStyle {
        switch status {
        case .setupFailed, .checksRunning: AnyShapeStyle(Palette.warning)
        case .awaitingPermission: AnyShapeStyle(Palette.negative)
        case .conflicted, .checksFailing: AnyShapeStyle(Palette.negative)
        case .checksPassed: AnyShapeStyle(Palette.positive)
        case .merged: AnyShapeStyle(Palette.merged)
        case .unread, .pullRequestOpen: AnyShapeStyle(Palette.accent)
        case .running: AnyShapeStyle(Palette.running)
        case .changed: AnyShapeStyle(.secondary)
        case .settingUp, .closed, .draft, .clean: AnyShapeStyle(.tertiary)
        }
    }
}
