import Foundation

public struct DocumentPreviewExitGate: Sendable, Equatable {
    public private(set) var isAsking = false
    public private(set) var isSilenced = false

    public init() {}

    public mutating func begin() -> Bool {
        guard !isAsking, !isSilenced else { return false }
        isAsking = true
        return true
    }

    public mutating func answered(opened: Bool) {
        isAsking = false
        if !opened { isSilenced = true }
    }

    public mutating func reloaded() {
        isSilenced = false
    }
}
