import Foundation

public struct ProfileDraft: Equatable, Sendable {
    public static let nameRequired = "A profile needs a name."

    public var name: String
    public var colour: String
    public var symbol: String

    public init(editing profile: Profile) {
        self.init(name: profile.name, colour: profile.colour, symbol: profile.symbol)
    }

    private init(name: String, colour: String, symbol: String) {
        self.name = name
        self.colour = colour
        self.symbol = symbol
    }

    public static func new(among profiles: [Profile]) -> ProfileDraft {
        let colours = Set(profiles.map(\.colour))
        let symbols = Set(profiles.map(\.symbol))
        return ProfileDraft(
            name: "",
            colour: Accent.all.first { !colours.contains($0) } ?? Accent.all[0],
            symbol: (ProfileChoices.symbols.first { !symbols.contains($0.name) } ?? ProfileChoices.symbols[0]).name
        )
    }

    public var savedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var nameProblem: String? { savedName.isEmpty ? Self.nameRequired : nil }

    public var canSave: Bool { nameProblem == nil }
}
