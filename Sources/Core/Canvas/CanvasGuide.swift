public struct CanvasGuide: Sendable, Hashable {
    public var axis: CanvasAxis
    public var position: Double
    public var from: Double
    public var to: Double

    public init(axis: CanvasAxis, position: Double, from: Double, to: Double) {
        self.axis = axis
        self.position = position
        self.from = from
        self.to = to
    }
}
