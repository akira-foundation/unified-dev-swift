import Testing
import Foundation
@testable import Core

@Suite("Merge method choice")
struct MergeMethodChoiceTests {
    @Test("all three of GitHub's methods are offered, in GitHub's order")
    func offersThree() {
        #expect(MergeMethodChoice.offered == [.merge, .squash, .rebase])
    }

    @Test("every offered method can actually be performed")
    func everyMethodIsReal() {
        for method in MergeMethodChoice.offered {
            #expect(!method.phrase.isEmpty)
            #expect(method.flag == "--\(method.rawValue)")
        }
    }

    @Test(
        "the button promises the method in force",
        arguments: [
            (GitHub.MergeMethod.merge, "Merge"),
            (.squash, "Squash and merge"),
            (.rebase, "Rebase and merge"),
        ]
    )
    func buttonLabels(method: GitHub.MergeMethod, label: String) {
        #expect(method.buttonLabel == label)
    }

    @Test("the menu keeps GitHub's own wording, which is not always the button's")
    func menuLabels() {
        #expect(GitHub.MergeMethod.merge.label == "Merge commit")
        #expect(GitHub.MergeMethod.merge.buttonLabel == "Merge")
        #expect(GitHub.MergeMethod.squash.label == GitHub.MergeMethod.squash.buttonLabel)
        #expect(GitHub.MergeMethod.rebase.label == GitHub.MergeMethod.rebase.buttonLabel)
    }

    @Test("a project nobody has chosen for, in an app nobody has set, merges with a merge commit")
    func fallsBack() {
        #expect(MergeMethodChoice.resolve(project: nil, app: nil) == .merge)
        #expect(MergeMethodChoice.fallback == .merge)
    }

    @Test("a project nobody has chosen for follows the app default")
    func followsTheAppDefault() {
        #expect(MergeMethodChoice.resolve(project: nil, app: "rebase") == .rebase)
    }

    @Test("a project's own choice wins over the app default")
    func projectWins() {
        #expect(MergeMethodChoice.resolve(project: "squash", app: "rebase") == .squash)
    }

    @Test("a value this version cannot read falls through rather than leaving no method")
    func resolvesRubbish() {
        #expect(MergeMethodChoice.resolve(project: "", app: nil) == .merge)
        #expect(MergeMethodChoice.resolve(project: "fast-forward", app: "rebase") == .rebase)
        #expect(MergeMethodChoice.resolve(project: nil, app: "Squash") == .merge)
    }

    @Test("each method reads back as itself", arguments: MergeMethodChoice.offered)
    func resolvesEach(method: GitHub.MergeMethod) {
        #expect(MergeMethodChoice.resolve(project: method.rawValue, app: nil) == method)
        #expect(MergeMethodChoice.resolve(project: nil, app: method.rawValue) == method)
    }

    @Test("the choice is keyed by project, so two projects cannot share one convention")
    func keyIsPerProject() {
        let one = MergeMethodChoice.key(repoID: RepoID("alpha"))
        let other = MergeMethodChoice.key(repoID: RepoID("beta"))
        #expect(one != other)
        #expect(one == "repo.alpha.mergeMethod")
    }

    @Test("a chosen method survives the app being quit", .tags(.persistence), .scratchDirectory)
    func roundTrips() async throws {
        let store = try makeTestStore("merge-method")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))

        #expect(await MergeMethodChoice.load(repoID: repo.id, from: store) == .merge)

        await MergeMethodChoice.save(.rebase, repoID: repo.id, to: store)

        #expect(await MergeMethodChoice.load(repoID: repo.id, from: store) == .rebase)
    }

    @Test("choosing for one project leaves every other project alone", .tags(.persistence), .scratchDirectory)
    func scopedToOneProject() async throws {
        let store = try makeTestStore("merge-method")
        let mine = try await store.upsert(Repo(name: "mine", path: TestScratch.unique("mine")))
        let theirs = try await store.upsert(Repo(name: "theirs", path: TestScratch.unique("theirs")))

        await MergeMethodChoice.save(.squash, repoID: mine.id, to: store)

        #expect(await MergeMethodChoice.load(repoID: mine.id, from: store) == .squash)
        #expect(await MergeMethodChoice.load(repoID: theirs.id, from: store) == .merge)
    }

    @Test("a deliberate choice of the fallback is stored rather than left as silence",
          .tags(.persistence), .scratchDirectory)
    func storesTheFallbackToo() async throws {
        let store = try makeTestStore("merge-method")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))

        await MergeMethodChoice.save(.merge, repoID: repo.id, to: store)

        #expect(try await store.setting(MergeMethodChoice.key(repoID: repo.id)) == "merge")
    }

    @Test("the app default reaches every project that has not chosen, and only those",
          .tags(.persistence), .scratchDirectory)
    func appDefaultReachesUnchosenProjects() async throws {
        let store = try makeTestStore("merge-method")
        let chosen = try await store.upsert(Repo(name: "chosen", path: TestScratch.unique("chosen")))
        let open = try await store.upsert(Repo(name: "open", path: TestScratch.unique("open")))

        #expect(await MergeMethodChoice.appDefault(from: store) == .merge)

        await MergeMethodChoice.save(.merge, repoID: chosen.id, to: store)
        await MergeMethodChoice.saveAppDefault(.rebase, to: store)

        #expect(await MergeMethodChoice.appDefault(from: store) == .rebase)
        #expect(await MergeMethodChoice.load(repoID: chosen.id, from: store) == .merge)
        #expect(await MergeMethodChoice.load(repoID: open.id, from: store) == .rebase)
    }

    @Test("clearing a project's choice makes it follow the app default again",
          .tags(.persistence), .scratchDirectory)
    func clearingFollowsTheDefault() async throws {
        let store = try makeTestStore("merge-method")
        let repo = try await store.upsert(Repo(name: "r", path: TestScratch.unique("repo")))
        await MergeMethodChoice.saveAppDefault(.squash, to: store)
        await MergeMethodChoice.save(.rebase, repoID: repo.id, to: store)

        #expect(await MergeMethodChoice.projectChoice(repoID: repo.id, from: store) == .rebase)

        await MergeMethodChoice.save(nil, repoID: repo.id, to: store)

        #expect(await MergeMethodChoice.projectChoice(repoID: repo.id, from: store) == nil)
        #expect(try await store.setting(MergeMethodChoice.key(repoID: repo.id)) == nil)
        #expect(await MergeMethodChoice.load(repoID: repo.id, from: store) == .squash)
    }
}
