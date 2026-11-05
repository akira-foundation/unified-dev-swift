import Foundation

extension CanvasElement {
    public var text: CanvasText? {
        switch kind {
        case .text(let text), .note(let text): text
        default: nil
        }
    }

    public var isNote: Bool {
        if case .note = kind { true } else { false }
    }

    public func kind(replacingTextWith text: CanvasText) -> Kind {
        isNote ? .note(text) : .text(text)
    }
}
