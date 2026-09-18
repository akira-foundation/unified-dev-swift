import Foundation

public final class RowMeasurements<Value> {
    private struct Layout: Equatable {
        var revision: Int
        var width: Double
    }

    private var layout: Layout?
    private var measured: [String: Value?] = [:]

    public init() {}

    public func measurement(
        for row: String, revision: Int, width: Double, measure: () -> Value?
    ) -> Value? {
        let current = Layout(revision: revision, width: width)
        if layout != current {
            layout = current
            measured.removeAll(keepingCapacity: true)
        }
        if let known = measured[row] { return known }
        let value = measure()
        measured[row] = value
        return value
    }
}
