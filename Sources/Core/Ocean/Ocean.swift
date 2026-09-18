import Foundation

public struct Ocean: Sendable, Hashable, Identifiable {
    public var id: String { slug }

    public let name: String
    public let slug: String
    public let latitude: Double
    public let longitude: Double
    public var usedAt: Date?

    public init(name: String, slug: String, latitude: Double, longitude: Double, usedAt: Date? = nil) {
        self.name = name
        self.slug = slug
        self.latitude = latitude
        self.longitude = longitude
        self.usedAt = usedAt
    }
}

public struct OceanPick: Sendable, Hashable {
    public let ocean: Ocean
    public let isFirstUse: Bool
    public let remainingUndiscovered: Int

    public init(ocean: Ocean, isFirstUse: Bool, remainingUndiscovered: Int) {
        self.ocean = ocean
        self.isFirstUse = isFirstUse
        self.remainingUndiscovered = remainingUndiscovered
    }

    public var notice: String? {
        guard isFirstUse else { return nil }
        switch remainingUndiscovered {
        case 0:
            return "This workspace is the first to sail the \(ocean.name), and it was the last sea left. All of them have now been discovered."
        case 1:
            return "This workspace is the first to sail the \(ocean.name). One sea is still waiting to be discovered."
        default:
            return "This workspace is the first to sail the \(ocean.name). \(remainingUndiscovered) seas are still waiting to be discovered."
        }
    }
}

public enum OceanCatalog {
    public static let all: [Ocean] = parse(tsv: builtInTSV)

    public static func shouldClaim(
        userSuppliedName: String?,
        userSuppliedBranch: String?,
        isChatWorkspace: Bool,
        wantsAutomaticName: Bool,
        hasTask: Bool
    ) -> Bool {
        guard userSuppliedName == nil, userSuppliedBranch == nil else { return false }
        if isChatWorkspace { return wantsAutomaticName || !hasTask }
        return !hasTask
    }

    public static func parse(tsv: String) -> [Ocean] {
        tsv.components(separatedBy: .newlines).dropFirst().compactMap { line in
            let fields = line.components(separatedBy: "\t")
            guard fields.count == 4,
                  let latitude = Double(fields[2]),
                  let longitude = Double(fields[3]),
                  (-90.0...90.0).contains(latitude),
                  (-180.0...180.0).contains(longitude) else { return nil }
            let name = fields[0].trimmingCharacters(in: .whitespaces)
            let slug = fields[1].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, Git.isValidBranchName(slug) else { return nil }
            return Ocean(name: name, slug: slug, latitude: latitude, longitude: longitude)
        }
    }
}
