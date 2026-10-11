import Foundation

public actor SpendIndexer {
    private let store: Store
    private let home: URL
    private let environment: [String: String]
    private let calendar: Calendar
    private var isRunning = false

    public init(
        store: Store,
        home: URL = TranscriptHome.resolve(),
        environment: [String: String] = TranscriptHome.environment(),
        calendar: Calendar = .current
    ) {
        self.store = store
        self.home = home
        self.environment = environment
        self.calendar = calendar
    }

    public func refresh(budget: Int = TranscriptReader.defaultBudget) async throws -> SpendIndexOutcome {
        guard !isRunning else { return SpendIndexOutcome(finished: false) }
        isRunning = true
        defer { isRunning = false }

        var outcome = SpendIndexOutcome()
        var census = SpendCensus()
        let cursors = try await store.transcriptCursors()
        let sources = TranscriptSources.sources(home: home, environment: environment)

        for kind in AgentKind.allCases where !sources.contains(where: { $0.provider == kind }) {
            census[kind] = SpendProviderCensus(keepsTranscripts: false, files: 0, pending: 0)
        }

        for source in sources {
            let files = TranscriptSources.files(in: source)
            var pending = 0
            var visited = 0
            for file in files {
                if Task.isCancelled {
                    outcome.finished = false
                    break
                }
                visited += 1
                let work = TranscriptWork.decide(for: file, cursor: cursors[file.url.path])
                guard work != .unchanged else { continue }
                guard let read = try await consume(file, work: work, budget: budget) else {
                    outcome.unreadable += 1
                    continue
                }
                outcome.filesRead += 1
                outcome.bytesRead += read.bytesRead
                outcome.turns += read.turns
                outcome.abandonedLines += read.abandonedLines
                if !read.finished {
                    pending += 1
                    outcome.finished = false
                }
                await Task.yield()
            }
            census[source.provider] = SpendProviderCensus(
                keepsTranscripts: !files.isEmpty,
                files: files.count,
                pending: pending + (files.count - visited)
            )
        }

        try await save(census)
        return outcome
    }

    private func consume(
        _ file: TranscriptFile,
        work: TranscriptWork,
        budget: Int
    ) async throws -> (bytesRead: Int, turns: Int, abandonedLines: Int, finished: Bool)? {
        if work.startsOver { try await store.forgetSpend(ofFile: file.url.path) }

        var offset = work.offset
        var carry = work.carry
        var bytesRead = 0
        var turns = 0
        var abandoned = 0

        while true {
            let result: TranscriptReadResult
            do {
                result = try TranscriptReader.read(file, from: offset, carry: carry, budget: budget)
            } catch {
                return nil
            }
            bytesRead += result.bytesRead
            turns += result.records.count
            abandoned += result.abandonedLines
            offset = result.offset
            carry = result.carry

            try await store.record(
                SpendTurns.turns(for: result.records, in: file, calendar: calendar),
                reaching: TranscriptCursor(
                    path: file.url.path,
                    provider: file.provider,
                    size: file.size,
                    modifiedAt: file.modifiedAt,
                    offset: offset,
                    carry: carry
                )
            )

            if result.reachedEnd { return (bytesRead, turns, abandoned, true) }
            if Task.isCancelled { return (bytesRead, turns, abandoned, false) }
        }
    }

    private func save(_ census: SpendCensus) async throws {
        let encoded = try JSONEncoder().encode(census)
        try await store.setSetting(SpendCensus.settingKey, String(decoding: encoded, as: UTF8.self))
    }
}

public struct SpendIndexOutcome: Sendable, Hashable {
    public var filesRead: Int
    public var bytesRead: Int
    public var turns: Int
    public var finished: Bool
    public var abandonedLines: Int
    public var unreadable: Int

    public init(
        filesRead: Int = 0,
        bytesRead: Int = 0,
        turns: Int = 0,
        finished: Bool = true,
        abandonedLines: Int = 0,
        unreadable: Int = 0
    ) {
        self.filesRead = filesRead
        self.bytesRead = bytesRead
        self.turns = turns
        self.finished = finished
        self.abandonedLines = abandonedLines
        self.unreadable = unreadable
    }
}
