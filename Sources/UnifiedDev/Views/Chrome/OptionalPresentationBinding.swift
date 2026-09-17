import SwiftUI

extension Binding {
    func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        nonisolated(unsafe) let source = self

        return Binding<Bool>(
            get: { source.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { source.wrappedValue = nil }
            }
        )
    }
}
