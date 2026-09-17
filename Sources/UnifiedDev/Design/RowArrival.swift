import Core
import SwiftUI

struct RowArrival<ID: Hashable>: Equatable {
    private(set) var arriving: Set<ID> = []

    private var known: Set<ID> = []

    private var hasFilled = false

    mutating func absorb(_ ids: some Sequence<ID>) {
        let current = Set(ids)
        defer { known = current }

        guard hasFilled else {
            hasFilled = !current.isEmpty
            arriving = []
            return
        }

        arriving.formIntersection(current)
        arriving.formUnion(current.subtracting(known))
    }

    mutating func adopt(_ ids: some Sequence<ID>) {
        known = Set(ids)
        hasFilled = hasFilled || !known.isEmpty
        arriving = []
    }

    mutating func settle() {
        arriving = []
    }

    func isArriving(_ id: ID) -> Bool {
        arriving.contains(id)
    }
}

extension View {
    func arrivingRow(_ isArriving: Bool) -> some View {
        modifier(ArrivingRow(isArriving: isArriving))
    }

    func settlesArrivals<ID: Hashable>(_ arrival: Binding<RowArrival<ID>>) -> some View {
        modifier(ArrivalSettle(arrival: arrival))
    }
}

private struct ArrivingRow: ViewModifier {
    let isArriving: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasLanded = false

    private var settle: TranscriptMotion.Arrival? {
        isArriving ? TranscriptMotion.arrival(reduceMotion: reduceMotion) : nil
    }

    func body(content: Content) -> some View {
        let owed = settle
        content
            .opacity(hasLanded || owed == nil ? 1 : 0)
            .offset(y: hasLanded || owed == nil ? 0 : (owed?.rise ?? 0))
            .onAppear {
                guard let owed else {
                    hasLanded = true
                    return
                }
                withAnimation(.easeOut(duration: owed.seconds)) { hasLanded = true }
            }
    }
}

private struct ArrivalSettle<ID: Hashable>: ViewModifier {
    @Binding var arrival: RowArrival<ID>

    func body(content: Content) -> some View {
        content.task(id: arrival.arriving) {
            guard !arrival.arriving.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            arrival.settle()
        }
    }
}
