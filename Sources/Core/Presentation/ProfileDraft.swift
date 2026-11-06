import Foundation

public struct ProfileDraft: Equatable, Sendable {
    public static let nameRequired = "A profile needs a name."

    public let profileID: ProfileID?
    public var name: String
    public var colour: String
    public var symbol: String
    public var accounts: ProfileAccountSource
    public let storedAccounts: ProfileAccountSource?
    public let choosesAccounts: Bool

    public init(editing profile: Profile, accounts: ProfileAccountSource) {
        self.init(
            profileID: profile.id, name: profile.name, colour: profile.colour, symbol: profile.symbol,
            accounts: accounts, storedAccounts: accounts, choosesAccounts: !profile.isInitial
        )
    }

    private init(
        profileID: ProfileID?,
        name: String,
        colour: String,
        symbol: String,
        accounts: ProfileAccountSource,
        storedAccounts: ProfileAccountSource?,
        choosesAccounts: Bool
    ) {
        self.profileID = profileID
        self.name = name
        self.colour = colour
        self.symbol = symbol
        self.accounts = accounts
        self.storedAccounts = storedAccounts
        self.choosesAccounts = choosesAccounts
    }

    public var accountsChanged: Bool { storedAccounts != nil && storedAccounts != accounts }

    public var accountsFootnote: String {
        let base = switch accounts {
        case .inherits:
            "Uses the accounts of Unified and follows any change made there."
        case .own where storedAccounts == .own:
            "Has accounts of its own, signed in to below. An agent with no account here runs this Mac's own login."
        case .own:
            "Has accounts of its own, signed in to here once the profile is saved. "
                + "An agent with no account here runs this Mac's own login."
        }
        guard accountsChanged else { return base }
        let gone = switch accounts {
        case .inherits: " Projects that chose one of this profile's accounts go back to the default of Unified."
        case .own: " Projects that chose an account of Unified go back to this profile's default."
        }
        return base + gone
    }

    public static func accountsLabel(_ source: ProfileAccountSource) -> String {
        switch source {
        case .inherits: "Same as Unified"
        case .own: "Its own"
        }
    }

    public static func new(among profiles: [Profile]) -> ProfileDraft {
        let colours = Set(profiles.map(\.colour))
        let symbols = Set(profiles.map(\.symbol))
        return ProfileDraft(
            profileID: nil,
            name: "",
            colour: Accent.all.first { !colours.contains($0) } ?? Accent.all[0],
            symbol: (ProfileChoices.symbols.first { !symbols.contains($0.name) } ?? ProfileChoices.symbols[0]).name,
            accounts: .inherits,
            storedAccounts: nil,
            choosesAccounts: true
        )
    }

    public var savedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    public var nameProblem: String? { savedName.isEmpty ? Self.nameRequired : nil }

    public var canSave: Bool { nameProblem == nil }
}
