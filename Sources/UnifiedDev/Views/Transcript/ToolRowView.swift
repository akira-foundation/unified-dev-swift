import SwiftUI
import Core

struct ToolRowView: View {
    var use: AgentToolUse
    var presentation: ToolPresentation
    var home: TranscriptHome
    var result: AgentToolResult?
    var isError: Bool
    var refusal: ToolRefusal?
    var refusalReason: String = ""
    var durationMS: Int?
    var subagentActions: Int?
    var onOpenRun: (() -> Void)?
    var runUnavailable = false
    var isExpanded: Bool
    var onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onOpenRun {
                header(onOpenRun: onOpenRun)
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: SubagentRunLink.openActionName, onOpenRun)
            } else {
                ExpandableRowHeader(isExpanded: isExpanded, onToggle: onToggle) {
                    header(onOpenRun: nil)
                }
            }

            if isExpanded {
                ToolDetailView(use: use, result: result, refusal: refusal, refusalReason: refusalReason)
                    .padding(.leading, TranscriptLayout.detailIndent)
                    .padding(.trailing, TranscriptLayout.inset)
                    .padding(.bottom, TranscriptLayout.block)
                    .transition(.opacity)
            }
        }
        .modifier(ExpandableRow(isHovered: isHovered))
        .onHover { isHovered = $0 }
    }

    private func header(onOpenRun: (() -> Void)?) -> ToolRowHeader {
        ToolRowHeader(
            presentation: presentation,
            home: home,
            isError: isError,
            refusal: refusal,
            refusalReason: refusalReason,
            durationMS: durationMS,
            subagentActions: subagentActions,
            runUnavailable: runUnavailable,
            onOpenRun: onOpenRun,
            onToggle: onOpenRun == nil ? nil : onToggle,
            isExpanded: isExpanded,
            isHovered: isHovered
        )
    }
}
