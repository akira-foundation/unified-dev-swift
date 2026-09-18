import Foundation

public struct RevertAlert: Equatable, Sendable {
    public let title: String
    public let message: String

    public init?(_ outcome: RevertOutcome, filename: String) {
        switch outcome {
        case .reverted:
            return nil
        case let .refused(reason):
            title = "Nothing was reverted"
            message = reason
        case let .failed(detail):
            title = "Could not revert \(filename)"
            message = detail.isEmpty ? "Git gave no reason" : detail
        }
    }
}
