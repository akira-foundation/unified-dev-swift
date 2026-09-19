import Observation
import Core

@MainActor
@Observable
final class TabRenameField {
    static let shared = TabRenameField()

    var state = TabRenameState()
}
