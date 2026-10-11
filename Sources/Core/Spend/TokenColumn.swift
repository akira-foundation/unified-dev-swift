import Foundation

public enum TokenColumn: String, Sendable, CaseIterable, Identifiable {
    case freshInput
    case cacheRead
    case cacheWrite
    case output

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .freshInput: "Fresh input"
        case .cacheRead: "Cache read"
        case .cacheWrite: "Cache write"
        case .output: "Output"
        }
    }

    public func tokens(in usage: TokenUsage) -> Int {
        switch self {
        case .freshInput: usage.freshInput
        case .cacheRead: usage.cacheRead
        case .cacheWrite: usage.cacheWrite
        case .output: usage.output
        }
    }
}

extension SpendCost {
    public func amount(of column: TokenColumn) -> Double {
        switch column {
        case .freshInput: freshInput
        case .cacheRead: cacheRead
        case .cacheWrite: cacheWrite
        case .output: output
        }
    }
}
