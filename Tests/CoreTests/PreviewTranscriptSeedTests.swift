import Testing
import Foundation
@testable import Core

private func scenario(_ transcripts: [PreviewScenario.Transcript]) -> PreviewScenario {
    PreviewScenario(
        projects: [PreviewScenario.Project(name: "billing")],
        transcripts: transcripts
    )
}

private func seeder() throws -> PreviewScenarioSeeder {
    PreviewScenarioSeeder(
        manager: WorkspaceManager(store: try makeTestStore("preview-transcripts")),
        scratchRoot: TestScratch.unique("preview-scratch")
    )
}

@Suite("Preview transcript seeding")
struct PreviewTranscriptSeedTests {
    @Test("nothing is written when there is no transcript home to write into")
    func withoutAnOverrideNothingIsWritten() throws {
        let written = try seeder().seedTranscripts(scenario([.init()]), at: Date(), home: nil)
        #expect(written == 0)
    }

    @Test("a seeded transcript reads back as the turns it names")
    func seededTranscriptIsRead() throws {
        let home = URL(filePath: TestScratch.unique("transcript-home"), directoryHint: .isDirectory)
        let made = try seeder()
        let written = try made.seedTranscripts(
            scenario([.init(project: "billing", model: "claude-opus-5", daysAgo: 0, turns: 5)]),
            at: Date(),
            home: home
        )
        #expect(written == 1)

        let source = TranscriptSources.sources(home: home, environment: [:])[0]
        let files = TranscriptSources.files(in: source)
        #expect(files.count == 1)
        let result = try TranscriptReader.read(try #require(files.first), from: 0, carry: TranscriptCarry())
        #expect(result.records.count == 5)
        #expect(result.records.allSatisfy { $0.model == "claude-opus-5" })
        #expect(result.records.allSatisfy { $0.directory == made.projectsRoot + "/billing" })
    }

    @Test("a Codex transcript carries the model from its turn context")
    func seededCodexTranscript() throws {
        let home = URL(filePath: TestScratch.unique("transcript-home"), directoryHint: .isDirectory)
        let made = try seeder()
        _ = try made.seedTranscripts(
            scenario([.init(provider: .codex, project: "billing", model: "gpt-6-sol", turns: 3)]),
            at: Date(),
            home: home
        )
        let source = TranscriptSources.sources(home: home, environment: [:])[1]
        let file = try #require(TranscriptSources.files(in: source).first)
        let result = try TranscriptReader.read(file, from: 0, carry: TranscriptCarry())
        #expect(result.records.count == 3)
        #expect(result.records.allSatisfy { $0.model == "gpt-6-sol" })
    }

    @Test("a truncated transcript loses its last turn and nothing else")
    func truncatedTranscript() throws {
        let home = URL(filePath: TestScratch.unique("transcript-home"), directoryHint: .isDirectory)
        _ = try seeder().seedTranscripts(
            scenario([.init(project: "billing", turns: 6, truncated: true)]), at: Date(), home: home
        )
        let source = TranscriptSources.sources(home: home, environment: [:])[0]
        let file = try #require(TranscriptSources.files(in: source).first)
        let result = try TranscriptReader.read(file, from: 0, carry: TranscriptCarry())
        #expect(result.records.count == 5)
        #expect(result.offset < file.size)
    }

    @Test("padding makes one transcript bigger than another with the same turns")
    func paddingChangesSize() throws {
        let home = URL(filePath: TestScratch.unique("transcript-home"), directoryHint: .isDirectory)
        _ = try seeder().seedTranscripts(
            scenario([
                .init(project: "billing", turns: 4),
                .init(project: "billing", turns: 4, padding: 2_000),
            ]),
            at: Date(),
            home: home
        )
        let source = TranscriptSources.sources(home: home, environment: [:])[0]
        let sizes = TranscriptSources.files(in: source).map(\.size).sorted()
        #expect(sizes.count == 2)
        #expect(sizes[1] > sizes[0] * 2)
    }

    @Test("a transcript naming a project the scenario never creates is refused")
    func unknownProjectIsRefused() {
        let made = scenario([.init(project: "nowhere")])
        #expect(made.problems.contains { $0.contains("nowhere") })
    }

    @Test("a transcript with no turns is refused")
    func emptyTranscriptIsRefused() {
        #expect(scenario([.init(turns: 0)]).problems.isEmpty == false)
    }
}
