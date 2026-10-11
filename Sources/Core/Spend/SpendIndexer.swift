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
        environment: [String: String] = ProcessInfo.processInfo.environment,
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
        var census = try await loadCensus()
        let cursors = try await store.transcriptCursors()

        for source in TranscriptSources.sources(home: home, environment: environment) {
            let files = TranscriptSources.files(in: source)
            var pending = 0
            for file in files {
                if Task.isCancelled {
                    outcome.finished = false
                    break
                }
                let work = TranscriptWork.decide(for: file, cursor: cursors[file.url.path])
                guard work != .unchanged else { continue }
                let read = try await consume(file, work: work, budget: budget)
                outcome.filesRead += 1
                outcome.bytesRead += read.bytesRead
                outcome.records += read.records
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
                pending: pending,
                readAt: Date()
            )
        }

        try await save(census)
        return outcome
    }

    private func consume(
        _ file: TranscriptFile,
        work: TranscriptWork,
        budget: Int
    ) async throws -> (bytesRead: Int, records: Int, abandonedLines: Int, finished: Bool) {
        if work.startsOver { try await store.forgetSpend(ofFile: file.url.path) }

        var offset = work.offset
        var carry = work.carry
        var bytesRead = 0
        var records = 0
        var abandoned = 0

        while true {
            let result = try TranscriptReader.read(file, from: offset, carry: carry, budget: budget)
            bytesRead += result.bytesRead
            records += result.records.count
            abandoned += result.abandonedLines
            offset = result.offset
            carry = result.carry

            try await store.add(SpendDays.days(for: result.records, in: file, calendar: calendar))
            try await store.remember(TranscriptCursor(
                path: file.url.path,
                provider: file.provider,
                size: file.size,
                modifiedAt: file.modifiedAt,
                offset: offset,
                carry: carry
            ))

            if result.reachedEnd { return (bytesRead, records, abandoned, true) }
            if Task.isCancelled { return (bytesRead, records, abandoned, false) }
        }
    }

    private func loadCensus() async throws -> SpendCensus {
        guard let stored = try await store.setting(SpendCensus.settingKey),
              let census = try? JSONDecoder().decode(SpendCensus.self, from: Data(stored.utf8))
        else { return SpendCensus() }
        return census
    }

    private func save(_ census: SpendCensus) async throws {
        let encoded = try JSONEncoder().encode(census)
        try await store.setSetting(SpendCensus.settingKey, String(decoding: encoded, as: UTF8.self))
    }
}

public struct SpendIndexOutcome: Sendable, Hashable {
    public var filesRead: Int
    public var bytesRead: Int
    public var records: Int
    public var finished: Bool
    public var abandonedLines: Int

    public init(
        filesRead: Int = 0,
        bytesRead: Int = 0,
        records: Int = 0,
        finished: Bool = true,
        abandonedLines: Int = 0
    ) {
        self.filesRead = filesRead
        self.bytesRead = bytesRead
        self.records = records
        self.finished = finished
        self.abandonedLines = abandonedLines
    }
}
