import Foundation

enum CanvasDeliveryColumn {
    static let column = "canvas_document_path"

    static func migrate(_ db: SQLiteDatabase) throws {
        let columns = Set(try db.query("PRAGMA table_info(deliveries);").compactMap { $0.string("name") })
        guard !columns.contains(column) else { return }
        try db.execute("ALTER TABLE deliveries ADD COLUMN \(column) TEXT;")
    }
}
