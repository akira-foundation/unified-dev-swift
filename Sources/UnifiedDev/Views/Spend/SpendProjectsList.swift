import SwiftUI
import Core

struct SpendProjectsList: View {
    let projects: [SpendProjectLine]

    @State private var opened: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text("By project")
                .font(Typo.title)
                .accessibilityAddTraits(.isHeader)
            if projects.isEmpty {
                Text(SpendBoard.emptyLine)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            ForEach(projects) { project in
                DisclosureGroup(isExpanded: binding(for: project)) {
                    VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                        ForEach(project.sessions) { session in
                            sessionRow(session)
                        }
                    }
                    .padding(.leading, Metrics.gutter)
                } label: {
                    projectRow(project)
                }
            }
        }
    }

    private func binding(for project: SpendProjectLine) -> Binding<Bool> {
        Binding(
            get: { opened.contains(project.id) },
            set: { isOpen in
                if isOpen { opened.insert(project.id) } else { opened.remove(project.id) }
            }
        )
    }

    private func projectRow(_ project: SpendProjectLine) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Text(project.name)
                .font(Typo.labelEmphasis)
            Text(SpendLines.sessions(project.sessions.count))
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            Spacer(minLength: Metrics.spacingWide)
            Text(SpendFormat.tokens(project.spend.usage.total))
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
            Text(SpendFormat.money(project.spend.cost.total))
                .font(Typo.codeSmall)
                .frame(width: 100, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func sessionRow(_ session: SpendSessionLine) -> some View {
        HStack(spacing: Metrics.spacingWide) {
            Text(session.agentSessionID)
                .font(Typo.codeTiny)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(session.modelLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
            Spacer(minLength: Metrics.spacingWide)
            Text(SpendLines.turns(session.turns))
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            Text(SpendFormat.tokens(session.spend.usage.total))
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
            Text(SpendFormat.money(session.spend.cost.total))
                .font(Typo.codeSmall)
                .frame(width: 100, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
