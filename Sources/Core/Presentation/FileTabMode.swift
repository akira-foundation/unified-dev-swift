import Foundation

public enum FileTabMode: Sendable, Equatable, CaseIterable {
    case preview
    case source
    case edit

    public func title(hasPreview: Bool) -> String {
        switch self {
        case .preview: "Preview"
        case .source: hasPreview ? "Source" : "View"
        case .edit: "Edit"
        }
    }

    public static func choices(hasPreview: Bool, canEdit: Bool) -> [Self] {
        (hasPreview ? [.preview] : []) + [.source] + (canEdit ? [.edit] : [])
    }

    public static func current(
        prefersEditing: Bool, prefersPreview: Bool, hasPreview: Bool, canEdit: Bool
    ) -> Self {
        if prefersEditing && canEdit { return .edit }
        return hasPreview && prefersPreview ? .preview : .source
    }

    public func preferences(prefersPreview: Bool) -> (prefersEditing: Bool, prefersPreview: Bool) {
        switch self {
        case .preview: (false, true)
        case .source: (false, false)
        case .edit: (true, prefersPreview)
        }
    }
}
