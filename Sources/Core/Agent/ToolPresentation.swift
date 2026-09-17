import Foundation

public struct ToolPresentation: Equatable, Sendable {
    public var glyph: String
    public var label: String
    public var detail: String
    public var tint: ToolTint
    public var chips: [ToolChip] = []
    public var detailLead: CommandDisplay.Lead = .none
    public var literal: String?

    public var detailIsCode: Bool { literal != nil }

    public var detailLine: String {
        let lead = detailLead
        return lead.text.isEmpty ? detail : lead.text + lead.joiner + detail
    }

    public init(
        glyph: String,
        label: String,
        detail: String,
        tint: ToolTint,
        chips: [ToolChip] = [],
        detailLead: CommandDisplay.Lead = .none,
        literal: String? = nil
    ) {
        self.glyph = glyph
        self.label = label
        self.detail = detail
        self.tint = tint
        self.chips = chips
        self.detailLead = detailLead
        self.literal = literal
    }
}

public enum ToolChip: Equatable, Sendable {
    case code(String)
    case file(path: String)

    public var text: String {
        switch self {
        case .code(let text): text
        case .file(let path): ToolPresenter.basename(path)
        }
    }
}
