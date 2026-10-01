import Foundation
import UniformTypeIdentifiers

extension DocumentPreview {
    public static let contentSecurityPolicy = [
        "default-src 'self' \(scheme):",
        "script-src 'self' \(scheme): 'unsafe-inline'",
        "style-src 'self' \(scheme): 'unsafe-inline'",
        "img-src 'self' \(scheme): data: blob:",
        "font-src 'self' \(scheme): data:",
        "media-src 'self' \(scheme): data: blob:",
        "connect-src 'self' \(scheme):",
        "frame-src 'self' \(scheme):",
        "worker-src 'self' \(scheme):",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'none'",
    ].joined(separator: "; ")

    public static func contentType(forFile path: String) -> String {
        if hasPreview(path: path) { return "text/html; charset=utf-8" }
        let fileExtension = (path as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "js", "mjs", "cjs": return "text/javascript; charset=utf-8"
        case "json", "map": return "application/json; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "svg": return "image/svg+xml; charset=utf-8"
        case "wasm": return "application/wasm"
        default: break
        }
        guard let type = UTType(filenameExtension: fileExtension), let mime = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return type.conforms(to: .text) ? "\(mime); charset=utf-8" : mime
    }

    public static func responseHeaders(contentType: String, length: Int) -> [String: String] {
        [
            "Content-Type": contentType,
            "Content-Length": String(length),
            "Cache-Control": "no-store",
            "Content-Security-Policy": contentSecurityPolicy,
            "X-Content-Type-Options": "nosniff",
        ]
    }

    public static func fingerprint(forFile path: String, draft: String?) -> String {
        if let draft { return "draft:\(draft.hashValue)" }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else { return "missing" }
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        return "disk:\(size):\(modified)"
    }

    public static func fingerprint(forFiles paths: [String], draft: String?) -> String {
        guard let document = paths.first else { return "missing" }
        let assets = paths.dropFirst().sorted().map { fingerprint(forFile: $0, draft: nil) }
        return ([fingerprint(forFile: document, draft: draft)] + assets).joined(separator: "|")
    }
}
