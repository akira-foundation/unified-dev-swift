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

    @Test("All is by name, whatever order the store answered in, the way Finder orders them")
    func allIsByName() {
        let sections = ProjectPickerSections.build(
            repos: [repo("site10"), repo("harbour"), repo("atlas"), repo("Kestrel"), repo("site2")],
            activity: [:]
        )

        #expect(ProjectPickerSections.all(in: sections).map(\.name)
            == ["atlas", "harbour", "Kestrel", "site2", "site10"])
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

    @Test("a picker with one project offers no choice, and with two it does")
    func offersAChoice() {
        let one = ProjectPickerSections.build(repos: [repo("atlas")], activity: [:])
        let two = ProjectPickerSections.build(repos: [repo("atlas"), repo("harbour")], activity: [:])

        #expect(!ProjectPickerSections.offersAChoice(one))
        #expect(ProjectPickerSections.offersAChoice(two))
        #expect(!ProjectPickerSections.offersAChoice([]))
    }

    @Test("a hidden project counts towards the choice, because it can be picked")
    func hiddenCountsTowardsTheChoice() {
        let sections = ProjectPickerSections.build(
            repos: [repo("atlas"), repo("secret", hidden: true)], activity: [:]
        )

        #expect(ProjectPickerSections.offersAChoice(sections))
        #expect(ProjectPickerSections.all(in: sections).map(\.name) == ["atlas", "secret"])
    }

    @Test("a hidden project shows in All, where it can be marked, and never in Recent")
    func hiddenShowsInAllOnly() {
        let secret = repo("secret", hidden: true)
        let sections = ProjectPickerSections.build(
            repos: [secret, repo("atlas")], activity: [secret.id: at(1)]
        )

        #expect(sections.map(\.kind) == [.all])
        let all = ProjectPickerSections.all(in: sections)
        #expect(all.first { $0.name == "secret" }?.hidden == true)
        #expect(all.first { $0.name == "atlas" }?.hidden == false)
    }

    @Test("a section with nothing in it is not offered, so no heading stands over nothing")
    func anEmptySectionIsNotOffered() {
        let sections = ProjectPickerSections.build(repos: [repo("atlas")], activity: [:])

        #expect(sections.map(\.kind) == [.all])
        #expect(sections.allSatisfy { !$0.projects.isEmpty })
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

        #expect(sections[0].projects.count == 10)
        #expect(sections[1].projects.count == 15)
    }

    @Test("a section knows itself apart, so a list can hold both")
    func sectionsAreIdentifiable() {
        let atlas = repo("atlas")
        let sections = ProjectPickerSections.build(repos: [atlas], activity: [atlas.id: at(1)])

        #expect(Set(sections.map(\.id)).count == 2)
    }
}
