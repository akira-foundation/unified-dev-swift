import SwiftUI
import AppKit
import Core

struct DetectedApp: Identifiable, Hashable {
    var id: String { app.bundleID }
    let app: ExternalApp
    let url: URL
    let icon: NSImage
}

@MainActor
enum InstalledApps {
    private static let staleAfter: TimeInterval = 60

    private static var cache: [DetectedApp] = []
    private static var scannedAt: Date?
    private static var systemDefaults: [String: DetectedApp?] = [:]
    private static var defaultsScannedAt: Date?
    private static var listings: [URL: [String]] = [:]

    static var all: [DetectedApp] {
        if let scannedAt, Date.now.timeIntervalSince(scannedAt) < staleAfter { return cache }
        cache = scan()
        scannedAt = .now
        return cache
    }

    static func invalidate() {
        scannedAt = nil
        defaultsScannedAt = nil
        systemDefaults = [:]
    }

    private static func scan() -> [DetectedApp] {
        defer { listings = [:] }
        return EditorCatalog.catalogue(adding: OpenInCustomApps().apps).compactMap { app in
            guard let url = locate(app) else { return nil }
            return DetectedApp(app: app, url: url, icon: icon(at: url))
        }
    }

    private static func locate(_ app: ExternalApp) -> URL? {
        for bundleID in app.bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }
        for folder in folders {
            let url = folder.appendingPathComponent(app.fileName)
            guard app.matches(bundleID: Bundle(url: url)?.bundleIdentifier) else { continue }
            return url
        }
        return sweep(for: app)
    }

    private static func sweep(for app: ExternalApp) -> URL? {
        for folder in folders {
            for name in listing(of: folder) where app.matchesFileName(name) {
                let url = folder.appendingPathComponent(name)
                guard app.matches(bundleID: Bundle(url: url)?.bundleIdentifier) else { continue }
                return url
            }
        }
        return nil
    }

    private static func listing(of folder: URL) -> [String] {
        if let cached = listings[folder] { return cached }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        listings[folder] = names
        return names
    }

    private static let folders: [URL] = [
        "/Applications",
        "/Applications/Utilities",
        "/Applications/Setapp",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
        NSHomeDirectory() + "/Applications/JetBrains Toolbox",
    ].map { URL(fileURLWithPath: $0, isDirectory: true) }

    static func systemDefault(forFile path: String) -> DetectedApp? {
        if let defaultsScannedAt, Date.now.timeIntervalSince(defaultsScannedAt) >= staleAfter {
            systemDefaults = [:]
        }
        if systemDefaults.isEmpty { defaultsScannedAt = .now }

        let key = (path as NSString).pathExtension.lowercased()
        if let cached = systemDefaults[key] { return cached }

        var found: DetectedApp?
        if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: path)),
           let bundleID = Bundle(url: url)?.bundleIdentifier,
           EditorCatalog.needsSystemDefaultRow(bundleID: bundleID, adding: OpenInCustomApps().apps) {
            found = DetectedApp(
                app: ExternalApp(bundleID: bundleID, name: name(of: url), targets: .file),
                url: url,
                icon: icon(at: url)
            )
        }
        systemDefaults[key] = found
        return found
    }

    static func icon(at url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let sized = icon.copy() as? NSImage ?? icon
        sized.size = NSSize(width: 16, height: 16)
        return sized
    }

    static func name(of url: URL) -> String {
        let display = FileManager.default.displayName(atPath: url.path)
        return display.hasSuffix(".app") ? String(display.dropLast(4)) : display
    }
}
