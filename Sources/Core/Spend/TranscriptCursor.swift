import Foundation

public struct TranscriptCursor: Sendable, Hashable {
    public var path: String
    public var provider: AgentKind
    public var size: Int
    public var modifiedAt: Date
    public var offset: Int
    public var carry: TranscriptCarry

    public init(
        path: String,
        provider: AgentKind,
        size: Int,
        modifiedAt: Date,
        offset: Int,
        carry: TranscriptCarry = TranscriptCarry()
    ) {
        self.path = path
        self.provider = provider
        self.size = size
        self.modifiedAt = modifiedAt
        self.offset = offset
        self.carry = carry
    }
}

public enum TranscriptWork: Sendable, Equatable {
    case unchanged
    case grew(from: Int, carry: TranscriptCarry)
    case fresh

    public var startsOver: Bool { self == .fresh }

    public var offset: Int {
        switch self {
        case .unchanged: 0
        case .grew(let offset, _): offset
        case .fresh: 0
        }
    }

    public var carry: TranscriptCarry {
        switch self {
        case .grew(_, let carry): carry
        case .unchanged, .fresh: TranscriptCarry()
        }
    }

    static let clockGrain: TimeInterval = 0.001

    static func wasRewritten(_ seen: Date, _ remembered: Date) -> Bool {
        abs(seen.timeIntervalSince(remembered)) > clockGrain
    }

    public static func decide(for file: TranscriptFile, cursor: TranscriptCursor?) -> TranscriptWork {
        guard let cursor else { return .fresh }
        if file.size < cursor.offset || file.size < cursor.size { return .fresh }
        if file.size == cursor.size, wasRewritten(file.modifiedAt, cursor.modifiedAt) { return .fresh }
        if cursor.offset < file.size { return .grew(from: cursor.offset, carry: cursor.carry) }
        return .unchanged
    }
}
