import Foundation

public struct TranscriptContentKey: Hashable, Sendable {
    public let value: UInt64

    public init(_ combine: (inout Hasher) -> Void) {
        var hasher = Hasher()
        combine(&hasher)
        value = UInt64(bitPattern: Int64(hasher.finalize()))
    }
}
