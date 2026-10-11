import Foundation
import Testing
@testable import Core

@Suite("The sections of the project picker")
struct ProjectPickerSectionsTests {
    private func repo(_ name: String, hidden: Bool = false) -> Repo {
        Repo(name: name, path: "/tmp/\(name)", hidden: hidden)
    }

    private func at(_ hoursAgo: Double) -> Date {
        Date(timeIntervalSince1970: 1_000_000 - hoursAgo * 3_600)
    }

    @Test("Recent comes before All, and only those two exist")
    func twoSectionsInOrder() {
        let atlas = repo("atlas")
        let sections = ProjectPickerSections.build(repos: [atlas], activity: [atlas.id: at(1)])

        #expect(sections.map(\.kind) == [.recent, .all])
        #expect(sections.map(\.title) == ["Recent", "All"])
    }

    @Test("a project that is in Recent is in All as well, because All is all of them")
    func allHoldsEverything() {
        let atlas = repo("atlas")
        let harbour = repo("harbour")
        let sections = ProjectPickerSections.build(
            repos: [atlas, harbour], activity: [atlas.id: at(1)]
        )

        #expect(sections[0].projects.map(\.name) == ["atlas"])
        #expect(sections[1].projects.map(\.name) == ["atlas", "harbour"])
    }

    @Test("All is by name, whatever order the store answered in")
    func allIsByName() {
        let sections = ProjectPickerSections.build(
            repos: [repo("harbour"), repo("atlas"), repo("Kestrel")], activity: [:]
        )

        #expect(sections[0].projects.isEmpty)
        #expect(sections[1].projects.map(\.name) == ["atlas", "harbour", "Kestrel"])
    }

    @Test("Recent is by recency, not by name")
    func recentIsByRecency() {
        let atlas = repo("atlas")
        let harbour = repo("harbour")
        let sections = ProjectPickerSections.build(
            repos: [atlas, harbour], activity: [atlas.id: at(40), harbour.id: at(2)]
        )

        #expect(sections[0].projects.map(\.name) == ["harbour", "atlas"])
    }

    @Test("a hidden project shows in All, where it can be marked, and never in Recent")
    func hiddenShowsInAllOnly() {
        let secret = repo("secret", hidden: true)
        let sections = ProjectPickerSections.build(
            repos: [secret, repo("atlas")], activity: [secret.id: at(1)]
        )

        #expect(sections[0].projects.isEmpty)
        #expect(sections[1].projects.first { $0.name == "secret" }?.hidden == true)
        #expect(sections[1].projects.first { $0.name == "atlas" }?.hidden == false)
    }

    @Test("an empty Recent is still offered as a section, so the picker does not change shape")
    func emptyRecentIsKept() {
        let sections = ProjectPickerSections.build(repos: [repo("atlas")], activity: [:])

        #expect(sections.count == 2)
        #expect(sections[0].projects.isEmpty)
    }

    @Test("with no projects at all there are no sections to draw")
    func nothingAtAll() {
        #expect(ProjectPickerSections.build(repos: [], activity: [:]).isEmpty)
    }

    @Test("no more than ten projects are offered as recent")
    func recentIsCapped() {
        let repos = (1...15).map { repo("p\($0)") }
        var activity: [RepoID: Date] = [:]
        for (index, repo) in repos.enumerated() { activity[repo.id] = at(Double(15 - index)) }

        let sections = ProjectPickerSections.build(repos: repos, activity: activity)

        #expect(sections[0].projects.count == RecentProjects.limit)
        #expect(sections[1].projects.count == 15)
    }

    @Test("a section knows itself apart, so a list can hold both")
    func sectionsAreIdentifiable() {
        let sections = ProjectPickerSections.build(repos: [repo("atlas")], activity: [:])

        #expect(Set(sections.map(\.id)).count == 2)
    }
}
