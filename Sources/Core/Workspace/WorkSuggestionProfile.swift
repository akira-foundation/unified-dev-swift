import Foundation

public enum WorkSuggestionProfile {
    public enum Source: Sendable, Equatable {
        case noWorkspace
        case workspace(ProfileID?)
    }

    public static func profile(admitting source: Source, active: ProfileID) -> ProfileID? {
        switch source {
        case .noWorkspace: active
        case .workspace(let profile): profile
        }
    }

    public static func admits(project: ProfileID, from source: Source) -> Bool {
        switch source {
        case .noWorkspace: true
        case .workspace(let profile): profile == project
        }
    }
}
