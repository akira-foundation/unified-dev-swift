import Foundation

extension HomeListing {
    public var deletion: ArchiveDeletion? {
        let archived = groups.flatMap(\.rows).filter(\.isArchived)
        let measured = archived.compactMap(\.footprint)
        guard !measured.isEmpty, measured.count == archived.count else { return nil }
        return ArchiveDeletion(measured)
    }
}

extension ArchiveDeletion {
    public var actionTitle: String { "Delete \(footprints.count.formatted())" }
}
