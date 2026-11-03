import Foundation

public struct CanvasTextDraft: Sendable, Equatable {
    public let elementID: CanvasElementID
    public let original: CanvasText
    public let text: CanvasText
    public let measuredHeight: Double

    public init(elementID: CanvasElementID, original: CanvasText, text: CanvasText, measuredHeight: Double) {
        self.elementID = elementID
        self.original = original
        self.text = text
        self.measuredHeight = measuredHeight
    }
}
