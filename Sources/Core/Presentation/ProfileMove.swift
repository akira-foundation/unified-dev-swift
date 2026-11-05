public enum ProfileMove {
    public static func targets(for repo: Repo, among profiles: [Profile]) -> [Profile] {
        guard profiles.count > 1 else { return [] }
        return profiles.filter { $0.id != repo.profileID }
    }
}
