import SwiftUI
import Core

struct WorkspaceNameText: View {
    let workspaceID: WorkspaceID
    let name: String
    let isUnread: Bool

    private static let unreadWeight: Font.Weight = .medium

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frame: String?

    init(_ workspace: Workspace, isUnread: Bool) {
        self.workspaceID = workspace.id
        self.name = workspace.name
        self.isUnread = isUnread
    }

    init(workspaceID: WorkspaceID, name: String, isUnread: Bool = false) {
        self.workspaceID = workspaceID
        self.name = name
        self.isUnread = isUnread
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(name)
                .hidden()
                .accessibilityHidden(true)

            Text(frame ?? name)
                .accessibilityLabel(name)
        }
        .fontWeight(isUnread ? Self.unreadWeight : .regular)
        .clipped()
        .task(id: reveal?.id) { await play() }
    }

    private var reveal: WorkspaceNameReveal? {
        WorkspaceNameReveals.shared.reveal(for: workspaceID, showing: name)
    }

    private func play() async {
        guard let reveal, !reduceMotion else {
            frame = nil
            return
        }

        for step in 0...ScrambleReveal.steps {
            frame = ScrambleReveal.frame(target: name, step: step, seed: reveal.seed)
            guard step < ScrambleReveal.steps else { break }
            try? await Task.sleep(for: ScrambleReveal.interval)
            if Task.isCancelled { break }
        }

        frame = nil
    }
}
