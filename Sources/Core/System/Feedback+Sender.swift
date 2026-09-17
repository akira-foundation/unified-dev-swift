import Foundation

extension Feedback {
    public struct Sender: Sendable, Equatable {
        public let name: String
        public let email: String

        public init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }

    public static let senderNameKey = "feedback.senderName"
    public static let senderEmailKey = "feedback.senderEmail"

    public static func rememberedSender(_ defaults: UserDefaults = .standard) -> Sender {
        Sender(
            name: defaults.string(forKey: senderNameKey) ?? "",
            email: defaults.string(forKey: senderEmailKey) ?? ""
        )
    }

    public static func rememberSender(name: String?, email: String, in defaults: UserDefaults = .standard) {
        if let name {
            defaults.set(normalisedName(name), forKey: senderNameKey)
        }
        defaults.set(normalisedEmail(email), forKey: senderEmailKey)
    }
}
