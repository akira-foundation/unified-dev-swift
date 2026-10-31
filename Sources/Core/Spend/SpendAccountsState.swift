import Foundation

public enum SpendAccountsState: Sendable, Equatable {
    case notRead
    case failed
    case read([SpendAccountLine])

    public var lines: [SpendAccountLine] {
        guard case .read(let lines) = self else { return [] }
        return lines
    }

    public var status: String? {
        switch self {
        case .notRead: SpendLines.accountsNotRead
        case .failed: SpendLines.accountsFailed
        case .read(let lines): lines.isEmpty ? SpendBoard.emptyLine : nil
        }
    }
}
