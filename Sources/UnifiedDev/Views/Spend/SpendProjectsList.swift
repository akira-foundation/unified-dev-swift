import SwiftUI
import Core

struct SpendProjectsList: View {
    let projects: [SpendProjectLine]

    @State private var opened: Set<String> = []

    var body: some View {
        if projects.isEmpty {
            Text(SpendBoard.emptyLine).settingsFootnote()
        }
        ForEach(projects) { project in
            DisclosureGroup(isExpanded: binding(for: project)) {
                ForEach(project.sessions) { session in
                    LabeledContent {
                        Text(SpendLines.cost(session.spend)).monospacedDigit()
                    } label: {
                        Label(session.agentSessionID, systemImage: "circle.fill")
                            .labelStyle(SpendDotLabelStyle(
                                ink: Color(hexString: ProviderAccent.hex(for: session.provider))
                            ))
                        Text(session.modelLine + ", " + SpendLines.turns(session.turns))
                    }
                }
            } label: {
                LabeledContent {
                    Text(SpendLines.cost(project.spend)).monospacedDigit()
                } label: {
                    Text(project.name)
                    Text(SpendLines.sessions(project.sessions.count))
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
}
