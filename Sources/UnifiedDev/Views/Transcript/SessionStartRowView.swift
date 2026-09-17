import SwiftUI
import Core

struct SessionStartRowView: View {
    var info: AgentInit

    private var modelLabel: String {
        ComposerOption.label(for: info.model, in: ComposerOption.models)
    }

    private var permissionLabel: String {
        PermissionMode(rawValue: info.permissionMode)?.label(on: info.agentKind)
            ?? ComposerOption.titleCased(info.permissionMode)
    }

    var body: some View {
        HStack(spacing: TranscriptLayout.glyphGap) {
            TranscriptGlyph(symbol: "bolt.horizontal.circle")

            Text("Started with")
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
                .transcriptLabelColumn("Started with", font: Typo.label)

            if !info.model.isEmpty {
                Chip(text: modelLabel)
            }
            if !info.permissionMode.isEmpty {
                Chip(text: permissionLabel)
            }

            Spacer(minLength: 0)
        }
        .transcriptRowFrame()
    }
}
