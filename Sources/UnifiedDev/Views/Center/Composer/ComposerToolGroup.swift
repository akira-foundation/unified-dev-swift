import SwiftUI
import Core

struct ComposerToolGroup: View {
    var showsAgentControls: Bool
    var onQuickPrompt: (@MainActor (QuickPromptPanelRow) -> Void)?
    var projectQuickPrompts: [ProjectQuickPrompt]
    var onOpenQuickPrompts: (@MainActor () -> Void)?
    var onSideConversation: (@MainActor () -> Void)?
    var onAttach: @MainActor () -> Void
    var usesCLIChat: Binding<Bool>?
    var supportsCLIChat: Bool
    var height: CGFloat?

    @State private var isShowingQuickPrompts = false
    @State private var quickPromptDraft: QuickPromptFormDraft?

    private enum Tool: Hashable {
        case quickPrompts
        case sideConversation
        case attach
        case cliChat
    }

    private var tools: [Tool] {
        var tools: [Tool] = []
        if showsAgentControls, onQuickPrompt != nil { tools.append(.quickPrompts) }
        if onSideConversation != nil { tools.append(.sideConversation) }
        if showsAgentControls { tools.append(.attach) }
        if usesCLIChat != nil { tools.append(.cliChat) }
        return tools
    }

    var body: some View {
        let tools = self.tools
        if !tools.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                    if index > 0 { Hairline(axis: .vertical).padding(.vertical, Metrics.spacingSmall) }
                    segment(tool)
                }
            }
            .buttonStyle(.plain)
            .frame(height: height ?? Metrics.barHeight)
            .clipShape(Capsule())
            .glassEffect(.regular, in: Capsule())
            .overlay { Capsule().strokeBorder(Palette.border, lineWidth: Metrics.outline) }
        }
    }

    @ViewBuilder
    private func segment(_ tool: Tool) -> some View {
        switch tool {
        case .quickPrompts:
            Button {
                onOpenQuickPrompts?()
                isShowingQuickPrompts = true
            } label: {
                glyph("text.badge.plus", isOn: isShowingQuickPrompts)
            }
            .help("Insert a quick prompt")
            .accessibilityLabel("Quick prompts")
            .popover(isPresented: $isShowingQuickPrompts, arrowEdge: .top) {
                if let onQuickPrompt {
                    QuickPromptMenu(
                        catalog: QuickPromptCatalog.shared,
                        projectPrompts: projectQuickPrompts,
                        draft: $quickPromptDraft,
                        onPick: onQuickPrompt,
                        onClose: { isShowingQuickPrompts = false }
                    )
                    .environment(\.fontScale, 1)
                }
            }
        case .sideConversation:
            Button { onSideConversation?() } label: { glyph("questionmark.bubble", isOn: false) }
                .help("Ask a side question (/btw)")
                .accessibilityLabel("Ask a side question")
        case .attach:
            Button(action: onAttach) { glyph("paperclip", isOn: false) }
                .help("Attach a file")
                .accessibilityLabel("Attach a file")
        case .cliChat:
            let isOn = usesCLIChat?.wrappedValue ?? false
            Button { usesCLIChat?.wrappedValue.toggle() } label: {
                glyph(isOn ? "terminal.fill" : "terminal", isOn: isOn)
            }
            .disabled(!supportsCLIChat)
            .help(supportsCLIChat ? "Open this chat in the CLI" : "CLI chat supports Claude Code and Codex")
            .accessibilityLabel("Open chat in CLI")
            .accessibilityValue(isOn ? "On" : "Off")
        }
    }

    private func glyph(_ symbol: String, isOn: Bool) -> some View {
        Image(systemName: symbol)
            .font(Typo.label)
            .foregroundStyle(isOn ? Palette.accent : Palette.textSecondary)
            .padding(.horizontal, Metrics.spacing + Metrics.spacingSmall)
            .padding(.vertical, Metrics.spacingSmall)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}
