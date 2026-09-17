import CoreGraphics
import Foundation

public enum SplitAxis: String, Codable, Sendable, Hashable {
    case horizontal
    case vertical
}

public enum SplitDirection: String, Sendable, Hashable, CaseIterable {
    case left
    case right
    case up
    case down

    public var axis: SplitAxis {
        switch self {
        case .left, .right: .horizontal
        case .up, .down: .vertical
        }
    }

    public var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .up: "Up"
        case .down: "Down"
        }
    }
}

public indirect enum SplitNode: Codable, Sendable, Hashable {
    case pane(String)
    case split(axis: SplitAxis, ratio: Double, first: SplitNode, second: SplitNode)
}

public struct SplitPaneFrame: Sendable, Hashable {
    public var pane: String
    public var frame: CGRect
}

public struct SplitDividerFrame: Sendable, Hashable {
    public var path: [Int]
    public var axis: SplitAxis
    public var ratio: Double
    public var frame: CGRect
    public var span: Double
}

public struct SplitGeometry: Sendable, Hashable {
    public var panes: [SplitPaneFrame]
    public var dividers: [SplitDividerFrame]
}

public struct SplitLayout: Codable, Sendable, Hashable {
    public private(set) var root: SplitNode
    public private(set) var focus: String
    public private(set) var zoomed: String?

    public static let minimumRatio: Double = 0.05

    static func clampedRatio(_ ratio: Double, minimum: Double = minimumRatio) -> Double {
        min(max(ratio.isFinite ? ratio : 0.5, minimum), 1 - minimum)
    }

    public init(pane: String) {
        root = .pane(pane)
        focus = pane
    }

    public var panes: [String] { root.panes }

    public var paneCount: Int { root.paneCount }

    public func contains(_ pane: String) -> Bool { root.contains(pane) }

    public var isZoomed: Bool { zoomed != nil }

    @discardableResult
    public mutating func split(_ pane: String, axis: SplitAxis, into newPane: String) -> Bool {
        guard contains(pane), !contains(newPane) else { return false }
        root = root.splitting(pane, axis: axis, into: newPane)
        focus = newPane
        zoomed = nil
        return true
    }

    @discardableResult
    public mutating func close(_ pane: String) -> Bool {
        guard contains(pane), paneCount > 1, let removal = root.removing(pane),
              let remaining = removal.node else { return false }

        root = remaining
        if zoomed == pane { zoomed = nil }
        if focus == pane { focus = removal.promoted ?? remaining.panes[0] }
        return true
    }

    @discardableResult
    public mutating func move(
        _ pane: String, beside target: String, axis: SplitAxis, before: Bool
    ) -> Bool {
        guard pane != target, contains(pane), contains(target) else { return false }
        guard root.siblingSplit(pane, target).map({ $0.axis != axis || $0.isFirst != before }) ?? true
        else { return false }
        guard let removal = root.removing(pane), let remaining = removal.node else { return false }

        root = remaining.splitting(target, axis: axis, into: pane, before: before)
        focus = pane
        zoomed = nil
        return true
    }

    @discardableResult
    public mutating func exchange(_ pane: String, with other: String) -> Bool {
        guard pane != other, contains(pane), contains(other) else { return false }
        root = root.exchanging(pane, other)
        focus = pane
        return true
    }

    @discardableResult
    public mutating func setFocus(_ pane: String) -> Bool {
        guard contains(pane) else { return false }
        focus = pane
        return true
    }

    @discardableResult
    public mutating func moveFocus(_ direction: SplitDirection) -> Bool {
        guard zoomed == nil, let next = neighbour(of: focus, direction: direction) else {
            return false
        }
        focus = next
        return true
    }

    @discardableResult
    public mutating func toggleZoom() -> Bool {
        guard paneCount > 1 else { return false }
        zoomed = zoomed == nil ? focus : nil
        return true
    }

    public func neighbour(of pane: String, direction: SplitDirection) -> String? {
        let frames = geometry(in: CGSize(width: 1, height: 1), dividerThickness: 0).panes
        guard let source = frames.first(where: { $0.pane == pane })?.frame else { return nil }

        let epsilon = 1e-9
        var best: (distance: Double, overlap: Double, pane: String)?

        for candidate in frames where candidate.pane != pane {
            let frame = candidate.frame
            let distance: Double
            switch direction {
            case .left: distance = source.minX - frame.maxX
            case .right: distance = frame.minX - source.maxX
            case .up: distance = source.minY - frame.maxY
            case .down: distance = frame.minY - source.maxY
            }
            guard distance >= -epsilon else { continue }

            let overlap: Double = direction.axis == .horizontal
                ? min(frame.maxY, source.maxY) - max(frame.minY, source.minY)
                : min(frame.maxX, source.maxX) - max(frame.minX, source.minX)
            guard overlap > epsilon else { continue }

            if let current = best {
                let closer = distance < current.distance - epsilon
                let sameDistance = abs(distance - current.distance) <= epsilon
                guard closer || (sameDistance && overlap > current.overlap) else { continue }
            }
            best = (distance, overlap, candidate.pane)
        }

        return best?.pane
    }

    public func ratio(at path: [Int]) -> Double? { root.node(at: path)?.ratio }

    public func sides(at path: [Int]) -> (first: String?, second: String?)? {
        guard case .split(_, _, let first, let second)? = root.node(at: path) else { return nil }
        func leaf(_ node: SplitNode) -> String? {
            guard case .pane(let id) = node else { return nil }
            return id
        }
        return (leaf(first), leaf(second))
    }

    @discardableResult
    public mutating func setRatio(_ ratio: Double, at path: [Int]) -> Bool {
        let clamped = Self.clampedRatio(ratio)
        guard let updated = root.settingRatio(clamped, at: path) else { return false }
        root = updated
        return true
    }

    public func geometry(in size: CGSize, dividerThickness: Double) -> SplitGeometry {
        var panes: [SplitPaneFrame] = []
        var dividers: [SplitDividerFrame] = []
        let bounds = CGRect(origin: .zero, size: size)

        if let zoomed, contains(zoomed) {
            return SplitGeometry(panes: [SplitPaneFrame(pane: zoomed, frame: bounds)], dividers: [])
        }

        func walk(_ node: SplitNode, _ rect: CGRect, _ path: [Int]) {
            switch node {
            case .pane(let id):
                panes.append(SplitPaneFrame(pane: id, frame: rect))

            case .split(let axis, let ratio, let first, let second):
                let total = axis == .horizontal ? rect.width : rect.height
                let span = max(0, total - dividerThickness)
                let head = span * ratio

                if axis == .horizontal {
                    walk(first, CGRect(x: rect.minX, y: rect.minY, width: head, height: rect.height), path + [0])
                    dividers.append(SplitDividerFrame(
                        path: path,
                        axis: axis,
                        ratio: ratio,
                        frame: CGRect(
                            x: rect.minX + head,
                            y: rect.minY,
                            width: dividerThickness,
                            height: rect.height
                        ),
                        span: span
                    ))
                    walk(
                        second,
                        CGRect(
                            x: rect.minX + head + dividerThickness,
                            y: rect.minY,
                            width: span - head,
                            height: rect.height
                        ),
                        path + [1]
                    )
                } else {
                    walk(first, CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: head), path + [0])
                    dividers.append(SplitDividerFrame(
                        path: path,
                        axis: axis,
                        ratio: ratio,
                        frame: CGRect(
                            x: rect.minX,
                            y: rect.minY + head,
                            width: rect.width,
                            height: dividerThickness
                        ),
                        span: span
                    ))
                    walk(
                        second,
                        CGRect(
                            x: rect.minX,
                            y: rect.minY + head + dividerThickness,
                            width: rect.width,
                            height: span - head
                        ),
                        path + [1]
                    )
                }
            }
        }

        walk(root, bounds, [])
        return SplitGeometry(panes: panes, dividers: dividers)
    }

    public var encoded: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public init?(encoded: String) {
        guard let data = encoded.data(using: .utf8),
              var layout = try? JSONDecoder().decode(SplitLayout.self, from: data) else {
            return nil
        }
        layout.repair()
        self = layout
    }

    public mutating func repair() {
        root = root.repaired(minimumRatio: Self.minimumRatio)
        if let zoomed, !contains(zoomed) { self.zoomed = nil }
        if !contains(focus) { focus = root.panes[0] }
    }
}

extension SplitNode {
    var panes: [String] {
        switch self {
        case .pane(let id): [id]
        case .split(_, _, let first, let second): first.panes + second.panes
        }
    }

    var paneCount: Int {
        switch self {
        case .pane: 1
        case .split(_, _, let first, let second): first.paneCount + second.paneCount
        }
    }

    var ratio: Double? {
        switch self {
        case .pane: nil
        case .split(_, let ratio, _, _): ratio
        }
    }

    func contains(_ pane: String) -> Bool {
        switch self {
        case .pane(let id): id == pane
        case .split(_, _, let first, let second): first.contains(pane) || second.contains(pane)
        }
    }

    func node(at path: [Int]) -> SplitNode? {
        guard let index = path.first else { return self }
        guard case .split(_, _, let first, let second) = self else { return nil }
        return (index == 0 ? first : second).node(at: Array(path.dropFirst()))
    }

    func splitting(
        _ pane: String, axis: SplitAxis, into newPane: String, before: Bool = false
    ) -> SplitNode {
        switch self {
        case .pane(let id):
            guard id == pane else { return self }
            return before
                ? .split(axis: axis, ratio: 0.5, first: .pane(newPane), second: .pane(id))
                : .split(axis: axis, ratio: 0.5, first: .pane(id), second: .pane(newPane))

        case .split(let axis0, let ratio, let first, let second):
            return .split(
                axis: axis0,
                ratio: ratio,
                first: first.splitting(pane, axis: axis, into: newPane, before: before),
                second: second.splitting(pane, axis: axis, into: newPane, before: before)
            )
        }
    }

    func siblingSplit(_ pane: String, _ other: String) -> (axis: SplitAxis, isFirst: Bool)? {
        guard case .split(let axis, _, let first, let second) = self else { return nil }
        if case .pane(let head) = first, case .pane(let tail) = second {
            if head == pane, tail == other { return (axis, true) }
            if head == other, tail == pane { return (axis, false) }
        }
        return first.siblingSplit(pane, other) ?? second.siblingSplit(pane, other)
    }

    func exchanging(_ pane: String, _ other: String) -> SplitNode {
        switch self {
        case .pane(let id):
            if id == pane { return .pane(other) }
            if id == other { return .pane(pane) }
            return self

        case .split(let axis, let ratio, let first, let second):
            return .split(
                axis: axis,
                ratio: ratio,
                first: first.exchanging(pane, other),
                second: second.exchanging(pane, other)
            )
        }
    }

    func removing(_ pane: String) -> (node: SplitNode?, promoted: String?)? {
        switch self {
        case .pane(let id):
            return id == pane ? (nil, nil) : nil

        case .split(let axis, let ratio, let first, let second):
            if let hit = first.removing(pane) {
                guard let remaining = hit.node else { return (second, second.panes.first) }
                return (.split(axis: axis, ratio: ratio, first: remaining, second: second), hit.promoted)
            }
            if let hit = second.removing(pane) {
                guard let remaining = hit.node else { return (first, first.panes.last) }
                return (.split(axis: axis, ratio: ratio, first: first, second: remaining), hit.promoted)
            }
            return nil
        }
    }

    func settingRatio(_ ratio: Double, at path: [Int]) -> SplitNode? {
        guard case .split(let axis, let current, let first, let second) = self else { return nil }
        guard let index = path.first else {
            return .split(axis: axis, ratio: ratio, first: first, second: second)
        }

        let child = index == 0 ? first : second
        guard let updated = child.settingRatio(ratio, at: Array(path.dropFirst())) else { return nil }
        return index == 0
            ? .split(axis: axis, ratio: current, first: updated, second: second)
            : .split(axis: axis, ratio: current, first: first, second: updated)
    }

    func repaired(minimumRatio: Double) -> SplitNode {
        guard case .split(let axis, let ratio, let first, let second) = self else { return self }
        return .split(
            axis: axis,
            ratio: SplitLayout.clampedRatio(ratio, minimum: minimumRatio),
            first: first.repaired(minimumRatio: minimumRatio),
            second: second.repaired(minimumRatio: minimumRatio)
        )
    }
}
