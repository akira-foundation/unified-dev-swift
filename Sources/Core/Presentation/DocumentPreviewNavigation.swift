import Foundation

public enum DocumentPreviewNavigation: Sendable, Equatable {
    case allow
    case openFile(String)
    case openExternally(URL)
    case refuse

    public static func decide(
        target: URL, document: String, root: String, isMainFrame: Bool, isLinkActivated: Bool
    ) -> Self {
        if target.scheme?.lowercased() == DocumentPreview.scheme {
            guard let file = DocumentPreview.file(for: target, root: root) else { return .refuse }
            if !isMainFrame { return .allow }
            let current = URL(filePath: document).standardizedFileURL.resolvingSymlinksInPath().path
            if file.path == current { return .allow }
            return isLinkActivated ? .openFile(file.path) : .refuse
        }
        if target.scheme?.lowercased() == "about" {
            guard !isMainFrame else { return .refuse }
            let name = target.absoluteString.lowercased()
            return name == "about:srcdoc" || name == "about:blank" ? .allow : .refuse
        }
        guard LinkPolicy.opens(target) else { return .refuse }
        return isMainFrame && isLinkActivated ? .openExternally(target) : .refuse
    }
}
