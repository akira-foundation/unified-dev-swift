import Foundation

struct CanvasPendingReload: Sendable {
    let document: CanvasDocument
    let disk: Data
    var backingUp: CanvasDocument?
}
