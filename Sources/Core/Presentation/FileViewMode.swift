import Foundation

public enum FileViewMode: String, Hashable, CaseIterable, Sendable {
    case diff = "Diff"
    case edit = "Edit"
}
