import Foundation

@MainActor
final class GeometryBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
