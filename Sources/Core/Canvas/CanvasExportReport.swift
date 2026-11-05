import Foundation

public struct CanvasExportFailure: Sendable, Equatable {
    public var frame: String
    public var reason: String

    public init(frame: String, reason: String) {
        self.frame = frame
        self.reason = reason
    }
}

public struct CanvasExportReport: Sendable, Equatable {
    public var directory: String
    public var written: [String]
    public var removed: [String]
    public var failed: [CanvasExportFailure]
    public var refused: [CanvasExportFailure]
    public var missingFonts: [String]
    public var missingImages: [String]

    public init(
        directory: String = "", written: [String] = [], removed: [String] = [], failed: [CanvasExportFailure] = [],
        refused: [CanvasExportFailure] = [], missingFonts: [String] = [], missingImages: [String] = []
    ) {
        self.directory = directory
        self.written = written
        self.removed = removed
        self.failed = failed
        self.refused = refused
        self.missingFonts = missingFonts
        self.missingImages = missingImages
    }

    public var hasProblems: Bool {
        !failed.isEmpty || !refused.isEmpty || !missingFonts.isEmpty || !missingImages.isEmpty
    }

    public func relativeDirectory(in worktree: String) -> String {
        let prefix = worktree.hasSuffix("/") ? worktree : worktree + "/"
        return directory.hasPrefix(prefix) ? String(directory.dropFirst(prefix.count)) : directory
    }

    public func title(in worktree: String) -> String {
        let place = relativeDirectory(in: worktree)
        guard !written.isEmpty else { return "Nothing was exported" }
        let count = written.count == 1 ? "1 frame" : "\(written.count) frames"
        return "Exported \(count) to \(place)"
    }

    public var lines: [String] {
        var lines: [String] = []
        if !removed.isEmpty {
            lines.append("Removed \(removed.count) older \(removed.count == 1 ? "picture" : "pictures") this export had written: \(removed.joined(separator: ", ")).")
        }
        for failure in failed { lines.append("Could not write \(failure.frame): \(failure.reason)") }
        for refusal in refused { lines.append("Left out \(refusal.frame): \(refusal.reason)") }
        if !missingFonts.isEmpty {
            lines.append("This Mac does not have \(missingFonts.joined(separator: ", ")), so text in those fonts is drawn in the system font.")
        }
        if !missingImages.isEmpty {
            lines.append("No picture file found for \(missingImages.joined(separator: ", ")), drawn as a placeholder.")
        }
        return lines
    }

    public var tone: NoticeTone {
        if written.isEmpty { return .error }
        return hasProblems ? .warning : .information
    }
}

public struct CanvasExportNotice: Sendable, Equatable {
    public var tone: NoticeTone
    public var title: String
    public var lines: [String]

    public init(tone: NoticeTone, title: String, lines: [String]) {
        self.tone = tone
        self.title = title
        self.lines = lines
    }

    public static func of(_ report: CanvasExportReport, in worktree: String) -> CanvasExportNotice {
        CanvasExportNotice(tone: report.tone, title: report.title(in: worktree), lines: report.lines)
    }

    public static func of(_ error: Error) -> CanvasExportNotice {
        CanvasExportNotice(tone: .error, title: "Nothing was exported", lines: [error.localizedDescription])
    }
}
