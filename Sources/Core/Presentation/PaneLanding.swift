import CoreGraphics
import Foundation

public enum PaneRegion: String, Sendable, Hashable, CaseIterable, Codable {
    case whole
    case leading
    case trailing
    case top
    case bottom

    public static let edgeShare: Double = 0.25

    public var placement: (axis: SplitAxis, before: Bool)? {
        switch self {
        case .whole: nil
        case .leading: (.horizontal, true)
        case .trailing: (.horizontal, false)
        case .top: (.vertical, true)
        case .bottom: (.vertical, false)
        }
    }

    public static func at(_ point: CGPoint, in size: CGSize) -> PaneRegion {
        guard size.width > 0, size.height > 0 else { return .whole }
        let horizontal = size.width * edgeShare
        let vertical = size.height * edgeShare

        if point.x < horizontal { return .leading }
        if point.x > size.width - horizontal { return .trailing }
        if point.y < vertical { return .top }
        if point.y > size.height - vertical { return .bottom }
        return .whole
    }

    public func frame(in pane: CGRect) -> CGRect {
        let share = Self.edgeShare
        switch self {
        case .whole:
            return pane
        case .leading:
            return CGRect(x: pane.minX, y: pane.minY, width: pane.width * share, height: pane.height)
        case .trailing:
            let width = pane.width * share
            return CGRect(x: pane.maxX - width, y: pane.minY, width: width, height: pane.height)
        case .top:
            return CGRect(x: pane.minX, y: pane.minY, width: pane.width, height: pane.height * share)
        case .bottom:
            let height = pane.height * share
            return CGRect(x: pane.minX, y: pane.maxY - height, width: pane.width, height: height)
        }
    }
}

public struct PaneLanding: Equatable, Sendable {
    public var pane: String
    public var region: PaneRegion
    public var frame: CGRect

    public init(pane: String, region: PaneRegion, frame: CGRect) {
        self.pane = pane
        self.region = region
        self.frame = frame
    }
}

extension SplitGeometry {
    public func landing(at point: CGPoint) -> PaneLanding? {
        guard let hit = panes.reversed().first(where: { $0.frame.contains(point) }) else { return nil }
        let local = CGPoint(x: point.x - hit.frame.minX, y: point.y - hit.frame.minY)
        let region = PaneRegion.at(local, in: hit.frame.size)
        return PaneLanding(pane: hit.pane, region: region, frame: region.frame(in: hit.frame))
    }
}
