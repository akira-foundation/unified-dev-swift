import Foundation

public enum DocumentPreviewNavigation: Sendable, Equatable {
    case allow
    case openFile(String)
    case openExternally(URL)
    case refuse

    public static func decide(
        target: URL, document: String, root: String, isMainFrame: Bool, isLinkActivated: Bool
    ) -> Self {
        switch target.scheme?.lowercased() ?? "" {
        case DocumentPreview.scheme:
            guard let file = DocumentPreview.file(for: target, root: root) else { return .refuse }
            if !isMainFrame { return .allow }
            let current = URL(filePath: document).standardizedFileURL.resolvingSymlinksInPath().path
            if file.path == current { return .allow }
            return isLinkActivated ? .openFile(file.path) : .refuse
        case "about":
            if isMainFrame { return target.absoluteString == "about:blank" ? .allow : .refuse }
            return target.absoluteString == "about:srcdoc" || target.absoluteString == "about:blank" ? .allow : .refuse
        case "http", "https", "mailto":
            return isMainFrame && isLinkActivated ? .openExternally(target) : .refuse
        default:
            return .refuse
        }
    }
}
