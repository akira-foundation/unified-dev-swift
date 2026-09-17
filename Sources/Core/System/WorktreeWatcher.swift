import Foundation
import CoreServices
import Synchronization

public final class WorktreeWatcher: Sendable {
    private let onChange: @Sendable (Set<String>) -> Void
    private let onFilesChanged: (@Sendable ([(path: String, type: Int)]) -> Void)?

    public static let latency: TimeInterval = 1

    private struct Watched {
        var stream: FSEventStreamRef?
        var given: [String] = []
        var matching: [String] = []
        var origins: [String: String] = [:]
        var metadata: [String: Set<String>] = [:]
    }

    private let watched = Mutex(Watched())
    private let queue = DispatchQueue(label: "io.akira.unifieddev.worktree-watcher", qos: .utility)

    public init(onFilesChanged: (@Sendable ([(path: String, type: Int)]) -> Void)? = nil,
                onChange: @escaping @Sendable (Set<String>) -> Void) {
        self.onChange = onChange
        self.onFilesChanged = onFilesChanged
    }

    deinit {
        watched.withLock { state in
            Self.tearDown(state.stream)
            state.stream = nil
        }
    }

    public func watch(roots: [String]) {
        let wanted = Self.ordered(roots)
        watched.withLock { state in
            guard state.given != wanted else { return }
            Self.tearDown(state.stream)
            state.given = wanted
            var origins: [String: String] = [:]
            for root in wanted { origins[Self.resolve(root)] = root }
            state.origins = origins
            state.matching = Self.ordered(Array(origins.keys))
            state.metadata = Self.metadataRoots(for: wanted)
            state.stream = wanted.isEmpty ? nil : makeStream(for: Array(Set(wanted + Array(state.metadata.keys))))
        }
    }

    public func stop() {
        watched.withLock { state in
            Self.tearDown(state.stream)
            state.stream = nil
            state.given = []
            state.matching = []
            state.origins = [:]
            state.metadata = [:]
        }
    }

    private func makeStream(for roots: [String]) -> FSEventStreamRef? {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagWatchRoot
        )

        let fileFlags = onFilesChanged == nil ? UInt32(0) : UInt32(kFSEventStreamCreateFlagFileEvents)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, count, paths, eventFlags, _ in
                guard let info, count > 0 else { return }
                let watcher = Unmanaged<WorktreeWatcher>.fromOpaque(info).takeUnretainedValue()
                let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
                watcher.report(changed)
                watcher.reportFiles(changed, flags: Array(UnsafeBufferPointer(start: eventFlags, count: count)))
            },
            &context,
            roots as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            Self.latency,
            flags | fileFlags
        ) else { return nil }

        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return nil
        }
        return stream
    }

    private static func tearDown(_ stream: FSEventStreamRef?) {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    private func report(_ paths: [String]) {
        let (matching, origins, metadata) = watched.withLock { ($0.matching, $0.origins, $0.metadata) }
        let files = paths.filter { path in
            !metadata.keys.contains { path == $0 || path.hasPrefix($0 + "/") }
        }
        var changed = Set(Self.roots(of: files, in: matching).compactMap { origins[$0] })
        changed.formUnion(Self.metadataWorktrees(changed: paths, metadata: metadata))
        guard !changed.isEmpty else { return }
        onChange(changed)
    }

    private func reportFiles(_ paths: [String], flags: [FSEventStreamEventFlags]) {
        guard let onFilesChanged else { return }
        let (matching, origins) = watched.withLock { ($0.matching, $0.origins) }
        let changes = zip(paths, flags).compactMap { path, flags -> (path: String, type: Int)? in
            let actual = Self.standardise(path)
            guard let root = matching.first(where: { actual.hasPrefix($0 + "/") }), let origin = origins[root] else { return nil }
            let given = origin + actual.dropFirst(root.count)
            let exists = FileManager.default.fileExists(atPath: given)
            let created = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
            return (given, exists ? (created ? 1 : 2) : 3)
        }
        if !changes.isEmpty { onFilesChanged(changes) }
    }

    static func metadataRoots(for roots: [String]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for root in roots {
            guard let paths = Git.repositoryPaths(in: root) else { continue }
            result[resolve(paths.gitDirectory), default: []].insert(root)
            result[resolve(paths.commonDirectory), default: []].insert(root)
        }
        return result
    }

    static func metadataWorktrees(changed paths: [String], metadata: [String: Set<String>]) -> Set<String> {
        var worktrees: Set<String> = []
        let ordered = Self.ordered(Array(metadata.keys))
        for path in paths {
            if let root = ordered.first(where: { path == $0 || path.hasPrefix($0 + "/") }) {
                let relative = path == root ? "" : String(path.dropFirst(root.count + 1))
                guard metadataAffectsWorktree(relative) else { continue }
                worktrees.formUnion(metadata[root] ?? [])
            }
        }
        return worktrees
    }

    private static func metadataAffectsWorktree(_ relative: String) -> Bool {
        let parts = relative.split(separator: "/").map(String.init)
        guard let first = parts.first else { return true }
        if first == "refs" {
            guard parts.count > 1 else { return true }
            return ["heads", "remotes", "tags"].contains(parts[1])
        }
        if first == "logs" {
            guard parts.count > 1 else { return true }
            return metadataAffectsWorktree(parts.dropFirst().joined(separator: "/"))
        }
        if first == "worktrees" { return parts.count == 1 }
        return [
            "HEAD", "index", "index.lock", "packed-refs", "packed-refs.lock", "config",
            "config.worktree", "commondir", "gitdir", "shallow", "MERGE_HEAD", "REBASE_HEAD",
            "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG", "rebase-apply", "rebase-merge", "sequencer",
        ].contains(first)
    }

    public static func roots(of paths: [String], in roots: [String]) -> Set<String> {
        var changed: Set<String> = []
        for path in paths {
            let standardised = standardise(path)
            for root in roots where standardised == root || standardised.hasPrefix(root + "/") {
                changed.insert(root)
                break
            }
        }
        return changed
    }

    public static func ordered(_ roots: [String]) -> [String] {
        Array(Set(roots.map(standardise))).sorted { $0.count > $1.count }
    }

    static func resolve(_ path: String) -> String {
        guard let real = realpath(path, nil) else { return standardise(path) }
        defer { free(real) }
        return standardise(String(cString: real))
    }

    private static func standardise(_ path: String) -> String {
        var trimmed = path
        while trimmed.count > 1, trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }
}
