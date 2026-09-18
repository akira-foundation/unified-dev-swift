import Testing
@testable import Core

@Suite("What Home says when it has nothing")
struct HomeEmptyStateTests {
    private func resolve(
        hasProjects: Bool = true,
        hasAnyWorkspace: Bool = true,
        isListEmpty: Bool = true,
        query: String = "",
        scope: HomeScope = .all,
        hasProjectFilter: Bool = false,
        projectPhrase: String = "that project"
    ) -> HomeEmptyState? {
        HomeEmptyState.resolve(
            hasProjects: hasProjects,
            hasAnyWorkspace: hasAnyWorkspace,
            isListEmpty: isListEmpty,
            query: query,
            scope: scope,
            hasProjectFilter: hasProjectFilter,
            projectPhrase: projectPhrase
        )
    }

    @Test("a machine with no projects is not reported as a search that matched nothing")
    func emptiestWins() {
        #expect(
            resolve(hasProjects: false, hasAnyWorkspace: false, query: "blue", hasProjectFilter: true)
                == .noProjects
        )
        #expect(
            resolve(hasAnyWorkspace: false, query: "blue", hasProjectFilter: true) == .noWorkspaces
        )
    }

    @Test("a list with rows in it says nothing")
    func aFullListSaysNothing() {
        #expect(resolve(isListEmpty: false) == nil)
        #expect(resolve(isListEmpty: false, query: "blue", hasProjectFilter: true) == nil)
    }

    @Test("a search that matched nothing is offered before a filter that hid everything")
    func theSearchIsUndoneFirst() {
        #expect(resolve(query: "blue", hasProjectFilter: true) == .noMatch(query: "blue", scope: .all))
        #expect(resolve(hasProjectFilter: true) == .noneInChosenProjects(phrase: "that project"))
    }

    @Test("a query of whitespace is not a search")
    func whitespaceIsNotASearch() {
        #expect(resolve(query: "   ", scope: .archived) == .emptyScope(.archived))
        #expect(resolve(query: "  blue  ") == .noMatch(query: "blue", scope: .all))
    }

    @Test("the last state left is the chip that is lit")
    func theLastOneIsTheScope() {
        #expect(resolve(scope: .archived) == .emptyScope(.archived))
        #expect(resolve(scope: .needsYou) == .emptyScope(.needsYou))
        #expect(resolve(scope: .running) == .emptyScope(.running))
        #expect(resolve(scope: .live) == .emptyScope(.live))
    }

    @Test("no two states share a title, a message or a button")
    func theStatesAreDistinct() {
        let states: [HomeEmptyState] = [
            .noProjects, .noWorkspaces, .noMatch(query: "blue", scope: .all),
            .noneInChosenProjects(phrase: "Unified Dev"), .emptyScope(.archived),
        ]
        #expect(Set(states.map(\.title)).count == states.count)
        #expect(Set(states.map(\.message)).count == states.count)
        for state in states {
            #expect(!state.title.isEmpty)
            #expect(!state.symbol.isEmpty)
            #expect(state.message.hasSuffix("."))
        }
    }

    @Test("each empty chip has a sentence of its own")
    func eachScopeSaysSomethingDifferent() {
        let scopes: [HomeScope] = [.needsYou, .running, .live, .archived]
        let states = scopes.map { HomeEmptyState.emptyScope($0) }
        #expect(Set(states.map(\.title)).count == scopes.count)
        #expect(Set(states.map(\.message)).count == scopes.count)
        for state in states { #expect(state.message.hasSuffix(".")) }
    }

    @Test("with no projects, the sentence says a repository you already have will do")
    func theFirstRunSentenceOffersAnExistingRepository() {
        let state = HomeEmptyState.noProjects

        #expect(state.title == "No projects yet")
        #expect(state.message.contains("repository you already have"))
        #expect(state.message != HomeEmptyState.emptyScope(.running).message)
        #expect(state.symbol != HomeEmptyState.emptyScope(.running).symbol)
    }

    @Test("every state offers exactly one way out, and names it as a verb")
    func everyStateHasOneWayOut() {
        #expect(HomeEmptyState.noProjects.actionTitle == "Start a project")
        let all: [HomeEmptyState] = [
            .noProjects, .noWorkspaces, .noMatch(query: "blue", scope: .all),
            .noneInChosenProjects(phrase: "Unified Dev"), .emptyScope(.archived),
        ]
        for state in all {
            #expect(!state.actionTitle.isEmpty, "\(state)")
        }
    }

    @Test("a search says which kind of thing it failed to find")
    func theSearchSentenceFollowsTheScope() {
        let all = HomeEmptyState.noMatch(query: "sidebar", scope: .all)
        let transcripts = HomeEmptyState.noMatch(query: "sidebar", scope: .transcripts)
        let workspaces = HomeEmptyState.noMatch(query: "sidebar", scope: .workspaces)
        #expect(all.message != transcripts.message)
        #expect(workspaces.message != transcripts.message)
        #expect(transcripts.title != workspaces.title)
    }

    @Test("the search sentence quotes the user properly")
    func theQuotesAreTypographic() {
        for scope in HomeScope.allCases {
            let message = HomeEmptyState.noMatch(query: "sidebar", scope: scope).message
            #expect(message.contains("\u{201C}sidebar\u{201D}"))
            #expect(!message.contains("\""))
        }
    }
}
