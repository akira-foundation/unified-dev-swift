import Core

enum DroppedFolders {
    static func paths(_ sources: [AttachmentSource]) -> [String?] {
        sources.map { source in
            guard case .file(let url) = source else { return nil }
            return url.standardizedFileURL.path
        }
    }
}
