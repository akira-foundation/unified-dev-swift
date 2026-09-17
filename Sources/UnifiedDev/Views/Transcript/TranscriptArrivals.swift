import Core
import SwiftUI

@MainActor
final class TranscriptArrivals {
    static let window = 200

    private var arrival = RowArrival<Int>()
    private var settle: Task<Void, Never>?

    func absorb(_ seqs: some Sequence<Int>) {
        arrival.absorb(seqs)
        scheduleSettle()
    }

    func adopt(_ seqs: some Sequence<Int>) {
        settle?.cancel()
        settle = nil
        arrival.adopt(seqs)
    }

    func isArriving(_ seq: Int) -> Bool {
        arrival.isArriving(seq)
    }

    private func scheduleSettle() {
        settle?.cancel()
        settle = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            settle = nil
            arrival.settle()
        }
    }
}
