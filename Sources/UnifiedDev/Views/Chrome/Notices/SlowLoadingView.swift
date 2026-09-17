import SwiftUI
import Core

struct SlowLoadingView<Subject: Equatable & Sendable>: View {
    var subject: Subject?
    var label: String?

    @State private var showing: Subject?

    var body: some View {
        Group {
            if let subject, showing == subject {
                LoadingView(label)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: subject) { await announceIfSlow() }
    }

    private func announceIfSlow() async {
        showing = nil
        guard let subject, let quiet = SlowWait.quiet() else { return }
        let clock = ContinuousClock()
        let began = clock.now
        try? await clock.sleep(for: quiet)
        guard SlowWait.isShowing(waited: began.duration(to: clock.now), isOver: Task.isCancelled)
        else { return }
        showing = subject
    }
}
