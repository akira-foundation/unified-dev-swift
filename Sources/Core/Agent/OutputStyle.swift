import Foundation

public struct OutputStyle: Identifiable, Hashable, Sendable {
    public var name: String
    public var detail: String
    public var isBuiltIn: Bool

    public var id: String { name }

    public init(name: String, detail: String, isBuiltIn: Bool = false) {
        self.name = name
        self.detail = detail
        self.isBuiltIn = isBuiltIn
    }

    public static let defaultName = "default"

    public static let unstyled = OutputStyle(
        name: defaultName,
        detail: "Claude writes the way it does with no style set",
        isBuiltIn: true
    )

    public static let builtIns: [OutputStyle] = [
        unstyled,
        OutputStyle(
            name: "Proactive",
            detail: "Claude executes immediately, minimizes interruptions, and prefers action over planning",
            isBuiltIn: true
        ),
        OutputStyle(
            name: "Concise",
            detail: "Claude responds tersely, leading with results and skipping preamble and narration",
            isBuiltIn: true
        ),
        OutputStyle(
            name: "Explanatory",
            detail: "Claude explains its implementation choices and codebase patterns",
            isBuiltIn: true
        ),
        OutputStyle(
            name: "Learning",
            detail: "Claude pauses and asks you to write small pieces of code for hands-on practice",
            isBuiltIn: true
        ),
    ]

    public static func isDefault(_ name: String?) -> Bool {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty || value == defaultName
    }
}
