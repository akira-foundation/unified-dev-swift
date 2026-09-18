import Foundation

public struct AttachmentHold: Equatable, Sendable {
    public var adopting: [String]
    public var releasing: [String]
    public var reinstating: [String]

    public init(adopting: [String] = [], releasing: [String] = [], reinstating: [String] = []) {
        self.adopting = adopting
        self.releasing = releasing
        self.reinstating = reinstating
    }

    public var changesHold: Bool { !releasing.isEmpty || !reinstating.isEmpty }

    public static func mounting(active: [String], released: [String], in draft: String) -> AttachmentHold {
        AttachmentHold(
            adopting: AttachmentDraft.unnamed(active, in: draft),
            reinstating: named(released, in: draft)
        )
    }

    public static func editing(active: [String], released: [String], in draft: String) -> AttachmentHold {
        AttachmentHold(
            releasing: AttachmentDraft.unnamed(active, in: draft),
            reinstating: named(released, in: draft)
        )
    }

    private static func named(_ released: [String], in draft: String) -> [String] {
        let unnamed = Set(AttachmentDraft.unnamed(released, in: draft))
        return released.filter { !unnamed.contains($0) }
    }
}
