import Foundation

public enum NoticePlacement: String, CaseIterable, Sendable, Hashable {
    case topCentre
    case topTrailing
    case aboveComposer

    public enum Edge: Sendable, Hashable {
        case top
        case trailing
        case bottom
    }

    public static let settingKey = "notices.placement"

    public static let standard = NoticePlacement.topCentre

    public init(stored: String?) {
        self = stored.flatMap(NoticePlacement.init(rawValue:)) ?? .standard
    }

    public var title: String {
        switch self {
        case .topCentre: "Top centre"
        case .topTrailing: "Top right"
        case .aboveComposer: "Bottom, above the composer"
        }
    }

    public var entrance: Edge {
        switch self {
        case .topCentre: .top
        case .topTrailing: .trailing
        case .aboveComposer: .bottom
        }
    }

    public var clearsComposer: Bool { self == .aboveComposer }

    public static func composerClearance(composerTops: [CGFloat], columnHeight: CGFloat) -> CGFloat {
        guard let highest = composerTops.min() else { return 0 }
        return min(max(columnHeight - highest, 0), columnHeight)
    }
}
