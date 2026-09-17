import SwiftUI
import Core

struct CrewSidebarRow: View {
    var row: CrewRow

    @Environment(\.backgroundProminence) private var prominence

    private var isOnSelection: Bool { prominence == .increased }

    var body: some View {
        Label {
            Text(row.name)
                .font(Typo.caption)
                .foregroundStyle(isOnSelection ? Palette.textInverted : Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            CrewMarkGlyph(state: row.state, isOnSelection: isOnSelection)
        }
        .labelStyle(SidebarRowLabelStyle())
        .padding(.leading, SidebarMetrics.crewIndent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(row.name))
        .accessibilityValue(Text(row.spokenState))
        .accessibilityCustomContent(Text("Subagent"), Text(row.name), importance: .high)
        .help("\(row.name): \(row.spokenState)")
    }
}

struct CrewRow: Identifiable, Equatable {
    var id: SessionID
    var name: String
    var state: SessionState

    init(_ session: Session) {
        id = session.id
        name = session.title
        state = session.state
    }

    var spokenState: String {
        switch state {
        case .idle: "Waiting for work"
        case .running: "Working"
        case .waiting: "Asking you something"
        case .failed: "Stopped with an error"
        case .cancelled: "Stopped"
        }
    }
}

struct CrewMarkGlyph: View {
    var state: SessionState
    var isOnSelection = false

    var body: some View {
        content
            .frame(width: Metrics.glyph, height: Metrics.glyph)
    }

    @ViewBuilder
    private var content: some View {
        if state == .running {
            WorkspaceRunningGlyph(isOnSelection: isOnSelection)
        } else {
            Image(systemName: Self.symbol(for: state))
                .font(Typo.micro)
                .imageScale(.medium)
                .foregroundStyle(isOnSelection ? Palette.textInverted : Self.tint(for: state))
                .accessibilityHidden(true)
        }
    }

    static func symbol(for state: SessionState) -> String {
        switch state {
        case .running: ""
        case .waiting: "questionmark.circle.fill"
        case .failed: "xmark"
        case .cancelled: "minus"
        case .idle: "circle"
        }
    }

    static func tint(for state: SessionState) -> Color {
        switch state {
        case .waiting: Palette.negative
        case .failed: Palette.negative
        case .running, .cancelled, .idle: Palette.textTertiary
        }
    }
}
