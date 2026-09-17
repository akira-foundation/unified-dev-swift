import Foundation

public enum CodexSendRecovery {
    public static func permitsNewTurn(after error: any Error) -> Bool {
        guard let refusal = error as? CodexRPCError,
              refusal.code == -32602 || refusal.code == -32000 else { return false }
        let message = refusal.message.lowercased()
        return message.contains("no active turn") || message.contains("turn is not active")
            || message.contains("expectedturnid") || message.contains("expected turn id")
            || message.contains("turn id mismatch")
    }
}
