import Foundation

public enum WorkSuggestionProfile {
    public enum Source: Sendable, Equatable {
        case noWorkspace
        case workspace(ProfileID?)
    }

    public static func admits(project: ProfileID, from source: Source) -> Bool {
        switch source {
        case .noWorkspace: true
        case .workspace(let profile): profile == project
        }
    }
}
