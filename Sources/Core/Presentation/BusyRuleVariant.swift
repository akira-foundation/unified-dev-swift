import Foundation

public enum BusyRuleVariant: String, CaseIterable, Sendable {
    case crest
    case current
    case swell

    public static let live = BusyRuleVariant.crest

    public var title: String {
        switch self {
        case .crest: "Crest"
        case .current: "Current"
        case .swell: "Swell"
        }
    }

    public var note: String {
        switch self {
        case .crest:
            "A lit track and one crest crossing it, head first, once every three seconds."
        case .current:
            "The crest repeated into a train, sliding one wavelength a beat."
        case .swell:
            "The whole width brightening and thickening at once. No travel, and no direction."
        }
    }

    public var travels: Bool { self != .swell }
}
