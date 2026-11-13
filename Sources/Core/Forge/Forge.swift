import Foundation

public enum Forge {
    private static let repositories = SharedReadings<String, ForgeRepository?>(retention: .seconds(600))
    private static let rememberedFor = Duration.seconds(300)

    @TaskLocal static var remoteOverride: (@Sendable (String) async -> String?)?

    public static func kind(forDirectory directory: String) async -> ForgeKind {
        guard let repository = await repository(forDirectory: directory) else { return .gitHub }
        return repository.kind
    }

    public static func repository(forDirectory directory: String) async -> ForgeRepository? {
        let read: @Sendable () async -> ForgeRepository? = {
            guard let remote = await baseRemoteURL(in: directory) else { return nil }
            return ForgeRepository.parse(remoteURL: remote)
        }
        if remoteOverride != nil { return await read() }
        return try? await repositories.value(for: directory, notOlderThan: rememberedFor, read: read)
    }

    private static func baseRemoteURL(in directory: String) async -> String? {
        if let remoteOverride { return await remoteOverride(directory) }
        return (try? await Git.repositoryContext(in: directory))?.baseRemoteURL
    }
}
