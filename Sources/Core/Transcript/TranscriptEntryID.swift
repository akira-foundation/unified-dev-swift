import Foundation

public enum TranscriptEntryID: Hashable, Sendable, CustomStringConvertible {
    case setup
    case row(Int)
    case fold(Int)
    case sending
    case streaming
    case pending(DeliveryID)
    case bottomSpacing

    public var seq: Int? {
        guard case .row(let seq) = self else { return nil }
        return seq
    }

    public var redrawsItself: Bool {
        switch self {
        case .row, .fold, .bottomSpacing: false
        case .setup, .sending, .streaming, .pending: true
        }
    }

    public var description: String {
        switch self {
        case .setup: "setup"
        case .row(let seq): "row.\(seq)"
        case .fold(let seq): "fold.\(seq)"
        case .sending: "sending"
        case .streaming: "streaming"
        case .pending(let id): "pending.\(id)"
        case .bottomSpacing: "bottomSpacing"
        }
    }
}
