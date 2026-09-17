import AppKit
import Foundation
import Observation
import Core

@MainActor
@Observable
final class BrowserFaviconStore {
    static let shared = BrowserFaviconStore()

    private(set) var icons: [String: NSImage] = [:]

    @ObservationIgnored private var entries: [String: Entry] = [:]

    @ObservationIgnored private var asked: Set<String> = []

    @ObservationIgnored private var hasWarmed = false

    @ObservationIgnored private var writer: Task<Void, Never>?

    private struct Entry: Codable, Sendable {
        var png: Data
        var seen: Date
    }

    private nonisolated static let fileName = "Favicons.plist"

    private static let writeDelay = Duration.seconds(1)

    private init() {}

    func icon(for address: String) -> NSImage? {
        guard let origin = BrowserFavicon.origin(of: address) else { return nil }
        return icons[origin]
    }

    func claim(_ origin: String) -> Bool {
        guard icons[origin] == nil, !asked.contains(origin) else { return false }
        asked.insert(origin)
        return true
    }

    func forget(_ origin: String) {
        asked.remove(origin)
    }

    func adopt(_ png: Data, for origin: String) {
        guard let image = Self.image(from: png) else { return }
        icons[origin] = image
        entries[origin] = Entry(png: png, seen: Date())
        save()
    }

    func warm() async {
        guard !hasWarmed else { return }
        hasWarmed = true

        let stored = await Task.detached(priority: .utility) { Self.read() }.value
        for (origin, entry) in stored where entries[origin] == nil {
            entries[origin] = entry
            guard icons[origin] == nil, let image = Self.image(from: entry.png) else { continue }
            icons[origin] = image
        }
    }

    private func save() {
        if entries.count > BrowserFavicon.cacheLimit {
            let doomed = entries.sorted { $0.value.seen < $1.value.seen }
                .prefix(entries.count - BrowserFavicon.cacheLimit)
            for (origin, _) in doomed { entries[origin] = nil }
        }

        let snapshot = entries
        writer?.cancel()
        writer = Task {
            try? await Task.sleep(for: Self.writeDelay)
            guard !Task.isCancelled else { return }
            await Task.detached(priority: .utility) { Self.write(snapshot) }.value
        }
    }

    private nonisolated static func read() -> [String: Entry] {
        let url = Store.defaultDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return [:] }
        guard data.count <= BrowserFavicon.cacheLimit * (BrowserFavicon.byteLimit + 256) else {
            return [:]
        }
        return (try? PropertyListDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private nonisolated static func write(_ entries: [String: Entry]) {
        let directory = Store.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
    }

    private static func image(from png: Data) -> NSImage? {
        guard png.count <= BrowserFavicon.byteLimit,
              let image = NSImage(data: png), image.isValid
        else { return nil }

        let ceiling = CGFloat(BrowserFavicon.pixels)
        let size = image.size
        guard size.width > 0, size.height > 0, size.width <= ceiling, size.height <= ceiling else {
            return nil
        }

        image.isTemplate = false
        return image
    }
}
