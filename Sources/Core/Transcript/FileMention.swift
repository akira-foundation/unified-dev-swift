import Foundation

public enum FileMention: Sendable {
    public static func names(_ span: String) -> Bool {
        guard FilePathGuess.looksLikeAFile(span) else { return false }
        if span.contains("/") { return true }
        guard let dot = span.lastIndex(of: ".") else { return false }
        return extensions.contains(span[span.index(after: dot)...].lowercased())
    }

    public static func segments(in text: String) -> [AttachmentDraft.Segment] {
        AttachmentDraft.parse(text, alsoNaming: names).segments
    }

    private static let extensions: Set<String> = [
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cs", "go", "rs", "java", "kt", "kts",
        "rb", "py", "php", "pl", "lua", "scala", "dart", "ex", "exs", "erl", "hs", "clj",
        "js", "mjs", "cjs", "ts", "tsx", "jsx", "vue", "svelte",
        "md", "markdown", "mdx", "txt", "rtf", "html", "htm", "xml", "svg", "css", "scss", "sass",
        "less", "twig", "erb", "haml", "hbs", "ejs", "pug",
        "json", "yml", "yaml", "toml", "ini", "cfg", "conf", "plist", "lock", "resolved",
        "gradle", "csv", "tsv", "sql", "graphql", "proto", "xcconfig", "pbxproj", "xib",
        "podspec", "gemspec",
        "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "mk", "cmake",
        "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "ico", "icns", "pdf",
        "mov", "mp4", "m4v", "webm", "gz", "tgz", "zip", "tar", "bz2", "xz", "dmg",
        "sqlite", "patch", "diff",
    ]
}
