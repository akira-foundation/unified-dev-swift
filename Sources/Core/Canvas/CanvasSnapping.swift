public enum CanvasSnapping {
    public static let tolerance = 6.0

    public static func snap(
        _ moving: CanvasRect, against others: [CanvasRect], frame: CanvasRect?
    ) -> (rect: CanvasRect, guides: [CanvasGuide]) {
        let targets = others + (frame.map { [$0] } ?? [])
        let horizontal = snapped(moving, targets: targets, axis: .vertical)
        var rect = moving
        rect.origin.x += horizontal.delta
        let vertical = snapped(rect, targets: targets, axis: .horizontal)
        rect.origin.y += vertical.delta
        return (rect, horizontal.guides + vertical.guides)
    }

    private static func anchors(of rect: CanvasRect, along axis: CanvasAxis) -> [Double] {
        let start = axis == .vertical ? rect.origin.x : rect.origin.y
        let length = axis == .vertical ? rect.size.width : rect.size.height
        return [start, start + length / 2, start + length]
    }

    private static func snapped(
        _ moving: CanvasRect, targets: [CanvasRect], axis: CanvasAxis
    ) -> (delta: Double, guides: [CanvasGuide]) {
        let mine = anchors(of: moving, along: axis)
        var best: Double?
        for target in targets {
            for position in anchors(of: target, along: axis) {
                for anchor in mine {
                    let delta = position - anchor
                    if abs(delta) <= tolerance, abs(delta) < abs(best ?? .infinity) { best = delta }
                }
            }
        }
        guard let delta = best else { return (0, []) }
        var result = moving
        if axis == .vertical { result.origin.x += delta } else { result.origin.y += delta }
        let guides = targets.flatMap { target in
            Set(anchors(of: target, along: axis).filter { position in
                anchors(of: result, along: axis).contains { abs($0 - position) < 0.001 }
            }).map { guide(at: $0, axis: axis, between: result, and: target) }
        }
        return (delta, guides.sorted { ($0.position, $0.from) < ($1.position, $1.from) })
    }

    private static func guide(at position: Double, axis: CanvasAxis, between a: CanvasRect, and b: CanvasRect) -> CanvasGuide {
        let along: (CanvasRect) -> (Double, Double) = { rect in
            axis == .vertical
                ? (rect.origin.y, rect.origin.y + rect.size.height)
                : (rect.origin.x, rect.origin.x + rect.size.width)
        }
        return CanvasGuide(axis: axis, position: position, from: min(along(a).0, along(b).0), to: max(along(a).1, along(b).1))
    }
}
