import Foundation

public struct WorkspaceNameSuggestion: Sendable, Hashable {
    public let name: String
    public let branch: String

    public init(name: String, branch: String) {
        self.name = name
        self.branch = branch
    }
}

public enum WorkspaceNaming {
    public static let placeholders: [String] = [
        "Alyssum", "Amaranth", "Anemone", "Angelica", "Aster", "Azalea", "Basil", "Bay",
        "Begonia", "Bellflower", "Bergamot", "Betony", "Bilberry", "Bindweed", "Bluebell",
        "Borage", "Bramble", "Briar", "Bryony", "Buttercup", "Calendula", "Camellia",
        "Campion", "Caraway", "Cardamom", "Catmint", "Cedar", "Celandine", "Chamomile",
        "Chervil", "Chicory", "Cinnamon", "Clematis", "Clover", "Columbine", "Comfrey",
        "Coriander", "Cornflower", "Cowslip", "Crocus", "Cyclamen", "Daffodil", "Dahlia",
        "Daisy", "Damson", "Dandelion", "Delphinium", "Dogwood", "Elder", "Fennel",
        "Fescue", "Feverfew", "Flax", "Foxglove", "Freesia", "Fuchsia", "Gardenia",
        "Gentian", "Geranium", "Ginger", "Gorse", "Hawthorn", "Hazel", "Heather",
        "Hellebore", "Hibiscus", "Hollyhock", "Honeysuckle", "Hyacinth", "Hydrangea",
        "Hyssop", "Iris", "Ivy", "Jasmine", "Juniper", "Laburnum", "Larkspur", "Lavender",
        "Lilac", "Linden", "Lobelia", "Lovage", "Lupin", "Magnolia", "Mallow", "Marigold",
        "Marjoram", "Meadowsweet", "Mimosa", "Mint", "Mistletoe", "Mullein", "Myrtle",
        "Narcissus", "Nasturtium", "Nettle", "Nigella", "Oleander", "Orchid", "Oregano",
        "Pansy", "Parsley", "Peony", "Periwinkle", "Petunia", "Phlox", "Pimpernel",
        "Poppy", "Primrose", "Privet", "Ragwort", "Rosemary", "Rowan", "Rue", "Saffron",
        "Sage", "Salvia", "Scabious", "Snapdragon", "Snowdrop", "Sorrel", "Speedwell",
        "Spurge", "Sunflower", "Sweetbriar", "Tansy", "Tarragon", "Thistle", "Thyme",
        "Trefoil", "Tulip", "Valerian", "Verbena", "Veronica", "Vervain", "Vetch",
        "Viburnum", "Wallflower", "Willow", "Wisteria", "Wormwood", "Yarrow", "Zinnia",
    ]

    public static func placeholder(
        avoiding taken: Set<String>,
        using generator: inout some RandomNumberGenerator
    ) -> String {
        let free = placeholders.filter { !taken.contains($0) }
        if let choice = free.randomElement(using: &generator) { return choice }

        let base = placeholders.randomElement(using: &generator) ?? "Seedling"
        var suffix = 2
        while taken.contains("\(base) \(suffix)") { suffix += 1 }
        return "\(base) \(suffix)"
    }

    public static func placeholder(avoiding taken: Set<String>) -> String {
        var generator = SystemRandomNumberGenerator()
        return placeholder(avoiding: taken, using: &generator)
    }

    public static func isPlaceholder(_ name: String) -> Bool {
        let base = name.components(separatedBy: " ").first ?? name
        return placeholders.contains(base)
    }

    public static let nameLimit = 60

    public static func suggestion(
        name rawName: String?,
        branch rawBranch: String?,
        branchPrefix: String? = nil
    ) -> WorkspaceNameSuggestion? {
        guard let name = WorkspaceName.given(cleanName(rawName)) else { return nil }
        let branch = cleanBranch(rawBranch, prefix: branchPrefix) ?? ""
        return WorkspaceNameSuggestion(name: name, branch: branch)
    }

    public static func cleanName(_ raw: String?) -> String? {
        guard let raw else { return nil }

        let firstLine = raw
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""

        var name = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)

        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`“”‘’*"))
        name = name.trimmingCharacters(in: .whitespaces)

        name = String(String.UnicodeScalarView(name.unicodeScalars.map {
            $0.value < 0x20 || $0.value == 0x7F ? " " : $0
        }))

        name = name
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        while name.hasSuffix(".") || name.hasSuffix(":") {
            name = String(name.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        guard !name.isEmpty else { return nil }

        if name.count > nameLimit {
            let cut = name.prefix(nameLimit)
            if let lastSpace = cut.lastIndex(of: " ") {
                name = String(cut[..<lastSpace])
            } else {
                name = String(cut)
            }
            name = name.trimmingCharacters(in: .whitespaces)
        }

        return name.isEmpty ? nil : name
    }

    public static func cleanBranch(_ raw: String?, prefix: String? = nil) -> String? {
        guard let raw else { return nil }
        let firstLine = raw
            .components(separatedBy: .newlines)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        guard !firstLine.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        let unprefixed: String
        if let slash = firstLine.firstIndex(of: "/") {
            unprefixed = String(firstLine[firstLine.index(after: slash)...])
                .replacingOccurrences(of: "/", with: " ")
        } else {
            unprefixed = firstLine
        }

        let slug = Git.slug(from: unprefixed)
        guard !slug.isEmpty, slug != "workspace" else { return nil }

        return prefixedBranch(slug, prefix: prefix)
    }

    public static func prefixedBranch(_ slug: String, prefix: String?) -> String? {
        let branch = Git.prefixed(slug, with: prefix)
        return Git.isValidBranchName(branch) ? branch : nil
    }

    public static func decode(cliOutput: Data) -> (name: String?, branch: String?)? {
        guard let root = (try? JSONSerialization.jsonObject(with: cliOutput)) as? [String: Any] else {
            return nil
        }

        if let structured = root["structured_output"] as? [String: Any] {
            return (structured["name"] as? String, structured["branch"] as? String)
        }

        guard let result = root["result"] as? String,
              let data = result.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        return (object["name"] as? String, object["branch"] as? String)
    }

    public static func shouldName(
        userSuppliedName: String?,
        prompt: String,
        isChatWorkspace: Bool,
        isEnabled: Bool,
        isAgentAvailable: Bool
    ) -> Bool {
        guard userSuppliedName == nil else { return false }
        guard isChatWorkspace else { return false }
        guard isEnabled, isAgentAvailable else { return false }
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func mayApplyName(current: String, placeholder: String) -> Bool {
        current == placeholder
    }

    public static func branchNotice(
        name: String,
        branch: String,
        refusal: BranchRenameRefusal
    ) -> String? {
        guard refusal.isWorthReporting else { return nil }
        return "Unified Dev named this workspace \(name). Its branch is still `\(branch)`, because "
            + refusal.reason + "."
    }
}

public struct WorkspaceNamingPreferences: @unchecked Sendable {
    public static let key = "naming.workspaces"

    public static let fallback = true

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? Self.fallback }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}
