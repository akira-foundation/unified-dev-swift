import Foundation

public enum DeliveryAbandonment {
    public static let stoppedBeforeSending = "Stopped before the message was sent."

    public static func complaint(for error: any Error) -> String {
        error is CancellationError ? stoppedBeforeSending : error.readableMessage
    }
}
