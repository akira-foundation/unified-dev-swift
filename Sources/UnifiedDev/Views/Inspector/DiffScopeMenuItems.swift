import SwiftUI
import Core

struct DiffScopeMenuItems: View {
    let model: WorkspaceModel

    var body: some View {
        let scope = model.diffScope

        Section {
            row(.all, subtitle: "Everything measured from \(model.workspace.baseBranch)", scope: scope)
            row(.uncommitted, subtitle: "Everything not committed yet", scope: scope)
        }

        if !model.branchCommits.commits.isEmpty {
            Section("Since a commit on this branch") {
                ForEach(model.branchCommits.commits) { commit in
                    row(
                        .since(commit),
                        title: commit.subject,
                        subtitle: "\(commit.abbreviated) · \(commit.author) · \(Self.age.localizedString(for: commit.date, relativeTo: .now))",
                        scope: scope
                    )
                }
                if let note = model.branchCommits.truncationNote {
                    Divider()
                    Text(note)
                }
            }
        }
    }

    private func row(
        _ target: DiffScope, title: String? = nil, subtitle: String, scope: DiffScope
    ) -> some View {
        Toggle(isOn: .init(
            get: { scope == target },
            set: { isOn in if isOn { model.setDiffScope(target) } }
        )) {
            Text(title ?? target.title)
            Text(subtitle)
        }
    }

    private static let age: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
