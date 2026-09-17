import Foundation
import Core

enum IntentDatabase {
    static func store() async throws -> Store {
        try await connection.store()
    }

    private static let connection = Connection()

    private actor Connection {
        private var opened: Store?

        func store() throws -> Store {
            if let opened { return opened }
            let store = try Store(path: try Store.defaultPath())
            self.opened = store
            return store
        }
    }
}
