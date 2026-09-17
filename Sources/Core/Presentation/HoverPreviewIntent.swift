public struct HoverPreviewIntent {
    private var isArmed = true

    public init() {}

    public mutating func keyPressed(
        keyCode: UInt16,
        hasModifiers: Bool,
        isRepeat: Bool,
        pointerMoved: Bool,
        isOverFile: Bool,
        hasSheet: Bool
    ) -> Bool {
        if pointerMoved { isArmed = true }
        guard keyCode == 49, !hasModifiers else { isArmed = false; return false }
        return isArmed && !isRepeat && isOverFile && !hasSheet
    }
}
