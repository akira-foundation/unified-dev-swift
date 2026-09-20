import Foundation
import Testing
@testable import Core

@Suite("The crew tools", .tags(.persistence), .scratchDirectory)
struct CrewToolTests {
    private struct Fixture {
        let store: Store
        let workspace: Workspace
        let orchestrator: Session

        var identity: BridgeIdentity {
            BridgeIdentity(sessionID: orchestrator.id, workspaceID: workspace.id, role: .workspace)
        }

        func identity(of session: Session) -> BridgeIdentity {
            BridgeIdentity(sessionID: session.id, workspaceID: workspace.id, role: .workspace)
        }
    }

    private func fixture(_ label: String) async throws -> Fixture {
        let store = try makeTestStore(label)
        let repo = try await store.upsert(Repo(name: "unifieddev", path: TestScratch.unique("repo")))
        let workspace = try await store.upsert(Workspace(
            repoID: repo.id, name: "crew", branch: "unifieddev/crew",
            path: TestScratch.unique("worktree"), baseBranch: "main"
        ))
        let orchestrator = try await store.upsert(Session(
            workspaceID: workspace.id, title: "Chat"
        ))
        return Fixture(store: store, workspace: workspace, orchestrator: orchestrator)
    }

    @discardableResult
    private func member(
        _ fixture: Fixture,
        _ name: String,
        of parent: Session? = nil,
        state: SessionState = .idle
    ) async throws -> Session {
        try await fixture.store.upsert(Session(
            workspaceID: fixture.workspace.id,
            parentSessionID: (parent ?? fixture.orchestrator).id,
            title: name,
            state: state
        ))
    }

    @discardableResult
    private func fillToCeiling(_ fixture: Fixture) async throws -> [Session] {
        var members: [Session] = []
        for slot in 1...Crew.ceiling {
            members.append(try await member(fixture, "slot-\(slot)", state: .running))
        }
        return members
    }

    private func request(
        _ tool: String, _ arguments: [String: JSONValue] = [:]
    ) -> MCPRequest {
        MCPRequest(id: .number(1), method: tool, params: .object(arguments))
    }

    private func answer(_ result: BridgeToolResult) throws -> JSONValue {
        try #require(JSONValue.parse(result.text))
    }

    private final class Starts: @unchecked Sendable {
        var orders: [CrewOrder] = []
        var callers: [SessionID] = []
        var workspaces: [WorkspaceID] = []
        var outcome: CrewStartOutcome = .started("Started.")

        func tool() -> AgentStartTool {
            AgentStartTool { [self] order, caller, workspace in
                orders.append(order)
                callers.append(caller)
                workspaces.append(workspace)
                return outcome
            }
        }
    }

    private final class Says: @unchecked Sendable {
        var targets: [String?] = []
        var messages: [String] = []
        var callers: [SessionID] = []
        var outcome: CrewSayOutcome = .delivered("Delivered.")

        func tool() -> AgentSayTool {
            AgentSayTool { [self] target, message, caller, _ in
                targets.append(target)
                messages.append(message)
                callers.append(caller)
                return outcome
            }
        }
    }

    private final class Stops: @unchecked Sendable {
        var names: [String] = []
        var callers: [SessionID] = []
        var outcome: CrewStopOutcome = .stopped("Stopped.")

        func tool() -> AgentStopTool {
            AgentStopTool { [self] name, caller, _ in
                names.append(name)
                callers.append(caller)
                return outcome
            }
        }
    }

    @Test("only a workspace agent sees them, and there is no fourth role")
    func roleGate() {
        let toolbox = BridgeToolbox(handlers: [
            Starts().tool(), Says().tool(), AgentListTool(), Stops().tool(),
        ])

        #expect(Starts().tool().roles == [.workspace])
        #expect(Says().tool().roles == [.workspace])
        #expect(AgentListTool().roles == [.workspace])
        #expect(Stops().tool().roles == [.workspace])

        #expect(toolbox.tools(for: .workspace).map(\.name)
            == ["agent_list", "agent_say", "agent_start", "agent_stop"])
        #expect(toolbox.tools(for: .owner).isEmpty)
        #expect(toolbox.handler(named: "agent_say", for: .owner) == nil)
        #expect(BridgeRole.allCases.count == 2)
    }

    @Test("only the listing is in the standard toolbox")
    func toolboxMembership() {
        let names = BridgeToolbox.standard.tools(for: .workspace).map(\.name)

        #expect(names.contains("agent_list"))
        #expect(!names.contains("agent_start"))
        #expect(!names.contains("agent_say"))
        #expect(!names.contains("agent_stop"))
        #expect(!BridgeToolbox.standard.tools(for: .owner).map(\.name).contains("agent_list"))
    }

    @Test("Unified Dev answers its own permission question about all four")
    func selfApproved() {
        for name in ["agent_start", "agent_say", "agent_list", "agent_stop"] {
            #expect(BridgeToolApproval.isSelfApproved(
                toolName: "\(BridgeToolApproval.toolPrefix)\(name)"
            ))
        }

        #expect(!BridgeToolApproval.selfApproved.contains("workspace_merge"))
        #expect(!BridgeToolApproval.selfApproved.contains("quick_prompt_delete"))
        #expect(!BridgeToolApproval.isSelfApproved(toolName: "agent_start"))
    }

    @Test("the schemas say what is required and nothing more")
    func schemas() {
        let start = Starts().tool().tool
        #expect(start.name == "agent_start")
        #expect(start.inputSchema["required"] == .array([.string("name"), .string("task")]))
        let startProperties = start.inputSchema["properties"]
        #expect(startProperties?["model"] != nil)
        #expect(startProperties?["effort"] != nil)
        #expect(startProperties?["workspace"] == nil)

        let say = Says().tool().tool
        #expect(say.inputSchema["required"] == .array([.string("message")]))
        #expect(say.inputSchema["properties"]?["to"] != nil)

        #expect(AgentListTool().tool.inputSchema == BridgeTool.noArguments)

        let stop = Stops().tool().tool
        #expect(stop.inputSchema["required"] == .array([.string("name")]))
    }

    @Test("the descriptions say the crew shares this branch and point at workspace_start")
    func theDescriptionsDrawTheLine() {
        let start = Starts().tool().tool.description
        #expect(start.contains("shares this worktree and this branch"))
        #expect(start.contains("one diff"))
        #expect(start.contains("workspace_start"))
        #expect(start.contains("\(Crew.ceiling)"))

        #expect(AgentListTool().tool.description.contains("shares this branch and these files"))
    }

    @Test("the descriptions tell this apart from the Task tool a model already has")
    func theDescriptionsNameTheTaskTool() {
        let start = Starts().tool().tool.description
        #expect(start.contains("Task tool"))
        #expect(start.contains("its own chat"))
        #expect(start.contains("outlives a single turn"))
        #expect(start.contains("agent_say"))
        #expect(start.contains("one-shot read"))

        #expect(Says().tool().tool.description.contains("Task subagent"))
        #expect(AgentListTool().tool.description.contains("Task subagents are not on this list"))
        #expect(Stops().tool().tool.description.contains("Task subagent"))
    }

    @Test("the descriptions say to finish with an agent, in Crew's one wording")
    func theDescriptionsSayToFinishWithOne() {
        #expect(Starts().tool().tool.description.contains(Crew.tidyHint))

        let stop = Stops().tool().tool.description
        #expect(stop.contains("ends that agent if it is still running"))
        #expect(stop.contains("takes its row out of the owner's sidebar"))
        #expect(stop.contains("frees its name"))
        #expect(stop.contains("its conversation stays in Unified Dev for the owner to read"))
        #expect(stop.contains("finish with an agent and not only how you interrupt one"))
    }

    @Test("a start reaches the window with the caller's own session and workspace on it")
    func startHandsOverTheOrder() async throws {
        let fixture = try await self.fixture("crew-start")
        let starts = Starts()

        let result = await starts.tool().call(
            request("agent_start", [
                "name": .string("  tests  "),
                "task": .string("Keep the suite green while I work on the parser."),
                "model": .string("opus"),
                "effort": .string("high"),
            ]),
            as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        #expect(starts.orders.count == 1)
        #expect(starts.orders.first?.name == "tests")
        #expect(starts.orders.first?.task == "Keep the suite green while I work on the parser.")
        #expect(starts.orders.first?.model == "opus")
        #expect(starts.orders.first?.effort == "high")
        #expect(starts.callers == [fixture.orchestrator.id])
        #expect(starts.workspaces == [fixture.workspace.id])
    }

    @Test("model and effort left out mean the ones the caller is running on")
    func modelAndEffortAreOptional() async throws {
        let fixture = try await self.fixture("crew-defaults")
        let starts = Starts()

        _ = await starts.tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("Run them.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(starts.orders.first?.model == nil)
        #expect(starts.orders.first?.effort == nil)
    }

    @Test("a subagent cannot start a subagent, and the window is never asked")
    func depthRefusal() async throws {
        let fixture = try await self.fixture("crew-depth")
        let crewMember = try await member(fixture, "tests")
        let starts = Starts()

        let result = await starts.tool().call(
            request("agent_start", ["name": .string("more"), "task": .string("Go.")]),
            as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text == Crew.sentence(for: .notAnOrchestrator))
        #expect(starts.orders.isEmpty)
    }

    @Test("the ceiling is counted over the running members of the whole workspace")
    func ceilingRefusal() async throws {
        let fixture = try await self.fixture("crew-ceiling")
        let filled = try await fillToCeiling(fixture)
        try await fixture.store.update(sessionID: filled[0].id) { $0.state = .waiting }
        let starts = Starts()

        let result = await starts.tool().call(
            request("agent_start", ["name": .string("one-too-many"), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text == Crew.sentence(for: .tooMany(running: Crew.ceiling)))
        #expect(result.text.contains("agent_stop"))
        #expect(starts.orders.isEmpty)
    }

    @Test("a stopped, failed or cancelled member does not hold a slot")
    func theDeadDoNotCount() async throws {
        let fixture = try await self.fixture("crew-census")
        let idle = try await member(fixture, "one", state: .idle)
        let failed = try await member(fixture, "two", state: .failed)
        let cancelled = try await member(fixture, "three", state: .cancelled)
        let running = try await member(fixture, "four", state: .running)

        #expect(!CrewCensus.isRunning(idle))
        #expect(!CrewCensus.isRunning(failed))
        #expect(!CrewCensus.isRunning(cancelled))
        #expect(CrewCensus.isRunning(running))

        let starts = Starts()
        let result = await starts.tool().call(
            request("agent_start", ["name": .string("five"), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        #expect(starts.orders.count == 1)
    }

    @Test("a name already in this workspace is refused, running or not")
    func duplicateNameRefusal() async throws {
        let fixture = try await self.fixture("crew-duplicate")
        try await member(fixture, "tests", state: .idle)
        let starts = Starts()

        let result = await starts.tool().call(
            request("agent_start", ["name": .string(" tests "), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text == Crew.sentence(for: .nameTaken("tests")))
        #expect(result.text.contains("agent_say"))
        #expect(starts.orders.isEmpty)
    }

    @Test("a name another chat's crew is using in this workspace is taken too")
    func duplicateAcrossChats() async throws {
        let fixture = try await self.fixture("crew-duplicate-other")
        let sibling = try await fixture.store.upsert(Session(
            workspaceID: fixture.workspace.id, title: "Second chat"
        ))
        try await member(fixture, "tests", of: sibling)
        let starts = Starts()

        let result = await starts.tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("already has a subagent called \"tests\""))
    }

    @Test("a blank name and a missing task are each refused with what to do instead")
    func theArgumentsAreRequired() async throws {
        let fixture = try await self.fixture("crew-arguments")
        let starts = Starts()

        let noName = await starts.tool().call(
            request("agent_start", ["name": .string("   "), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(noName.isError)
        #expect(noName.text == Crew.sentence(for: .noName))

        let noTask = await starts.tool().call(
            request("agent_start", ["name": .string("tests")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(noTask.isError)
        #expect(noTask.text.contains("cannot see this conversation"))

        let blankTask = await starts.tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("\n ")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(blankTask.isError)

        #expect(starts.orders.isEmpty)
    }

    @Test("a refusal from the window is passed through as an errored result")
    func theWindowMayStillRefuse() async throws {
        let fixture = try await self.fixture("crew-window-refusal")
        let starts = Starts()
        starts.outcome = .refused("The workspace is still installing.")

        let result = await starts.tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text == "The workspace is still installing.")
    }

    @Test("a connection speaking for no workspace is told so, by all four")
    func noWorkspaceOnTheToken() async throws {
        let fixture = try await self.fixture("crew-no-workspace")

        let start = await Starts().tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("Go.")]),
            as: .owner, store: fixture.store
        )
        let say = await Says().tool().call(
            request("agent_say", ["message": .string("hello")]),
            as: .owner, store: fixture.store
        )
        let list = await AgentListTool().call(
            request("agent_list"), as: .owner, store: fixture.store
        )
        let stop = await Stops().tool().call(
            request("agent_stop", ["name": .string("tests")]),
            as: .owner, store: fixture.store
        )

        for result in [start, say, list, stop] {
            #expect(result.isError)
            #expect(result.text.contains("not speaking for one"))
        }
    }

    @Test("a caller whose own chat has gone is told that, not told to try again")
    func theCallersRowHasGone() async throws {
        let fixture = try await self.fixture("crew-caller-gone")

        let result = await Starts().tool().call(
            request("agent_start", ["name": .string("tests"), "task": .string("Go.")]),
            as: BridgeIdentity(
                sessionID: SessionID("gone"), workspaceID: fixture.workspace.id, role: .workspace
            ),
            store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("no longer has the chat"))
    }

    @Test("a subagent talks up without naming anybody")
    func aSubagentTalksUp() async throws {
        let fixture = try await self.fixture("crew-say-up")
        let crewMember = try await member(fixture, "tests")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["message": .string("The parser tests pass now.")]),
            as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(!result.isError)
        #expect(says.targets == [nil])
        #expect(says.messages == ["The parser tests pass now."])
        #expect(says.callers == [crewMember.id])
    }

    @Test("a subagent naming its own orchestrator is allowed, and still goes up as nil")
    func namingYourOwnOrchestratorIsFine() async throws {
        let fixture = try await self.fixture("crew-say-named-up")
        let crewMember = try await member(fixture, "tests")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["to": .string("chat"), "message": .string("Done.")]),
            as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(!result.isError)
        #expect(says.targets == [nil])
    }

    @Test("a subagent naming a crewmate is refused, not quietly redirected")
    func aSubagentCannotTalkSideways() async throws {
        let fixture = try await self.fixture("crew-say-sideways")
        let crewMember = try await member(fixture, "tests")
        try await member(fixture, "docs")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["to": .string("docs"), "message": .string("Take this.")]),
            as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("\"Chat\" is the only agent you can talk to"))
        #expect(result.text.contains("Leave 'to' out"))
        #expect(says.messages.isEmpty)
    }

    @Test("an orchestrator must say who it is talking to")
    func anOrchestratorMustName() async throws {
        let fixture = try await self.fixture("crew-say-nobody")
        try await member(fixture, "tests")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["message": .string("Anybody?")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("needs 'to'"))
        #expect(result.text.contains("agent_list"))
        #expect(says.messages.isEmpty)
    }

    @Test("an orchestrator naming an agent that is not its own is refused with the names that are")
    func anOrchestratorCannotReachAcross() async throws {
        let fixture = try await self.fixture("crew-say-across")
        try await member(fixture, "tests")
        let sibling = try await fixture.store.upsert(Session(
            workspaceID: fixture.workspace.id, title: "Second chat"
        ))
        try await member(fixture, "theirs", of: sibling)
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["to": .string("theirs"), "message": .string("Hello.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("no subagent called 'theirs'"))
        #expect(result.text.contains("tests"))
        #expect(result.text.contains("agent_list"))
        #expect(says.messages.isEmpty)
    }

    @Test("an orchestrator with no crew at all is told that, rather than told to try another name")
    func anOrchestratorWithNoCrew() async throws {
        let fixture = try await self.fixture("crew-say-empty")

        let result = await Says().tool().call(
            request("agent_say", ["to": .string("tests"), "message": .string("Hello.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("started no subagents"))
        #expect(result.text.contains("agent_start"))
    }

    @Test("a blank message is refused rather than delivered as nothing")
    func aBlankMessage() async throws {
        let fixture = try await self.fixture("crew-say-blank")
        try await member(fixture, "tests")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", ["to": .string("tests"), "message": .string("  \n ")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("cannot be blank"))
        #expect(says.messages.isEmpty)
    }

    @Test("saying something to a stopped agent is refused when the workspace is already full")
    func wakingOneIsHeldToTheCeiling() async throws {
        let fixture = try await self.fixture("crew-say-ceiling")
        let filled = try await fillToCeiling(fixture)
        let stopped = filled[0]

        try await fixture.store.update(sessionID: stopped.id) { $0.state = .idle }

        let starts = Starts()
        let started = await starts.tool().call(
            request("agent_start", ["name": .string("replacement"), "task": .string("Go.")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(!started.isError)
        try await member(fixture, "replacement", state: .running)

        let says = Says()
        let result = await says.tool().call(
            request("agent_say", ["to": .string(stopped.title), "message": .string("Carry on.")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text == Crew.sentence(for: .tooMany(running: Crew.ceiling)))
        #expect(result.text.contains("agent_stop"))
        #expect(says.messages.isEmpty)
    }

    @Test("a full workspace still takes a message to a running agent, and a stopped one wakes when there is room")
    func sayingIsRefusedOnlyWhenItWouldStartAFourth() async throws {
        let fixture = try await self.fixture("crew-say-room")
        let filled = try await fillToCeiling(fixture)
        let running = filled[0]
        try await member(fixture, "spare", state: .cancelled)
        let says = Says()

        let toRunning = await says.tool().call(
            request("agent_say", ["to": .string(running.title), "message": .string("Also the parser.")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(!toRunning.isError)
        #expect(says.targets == [running.title])

        let toStopped = await says.tool().call(
            request("agent_say", ["to": .string("spare"), "message": .string("Try again.")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(toStopped.isError)
        #expect(toStopped.text == Crew.sentence(for: .tooMany(running: Crew.ceiling)))

        try await fixture.store.update(sessionID: running.id) { $0.state = .idle }

        let afterRoom = await says.tool().call(
            request("agent_say", ["to": .string("spare"), "message": .string("Try again.")]),
            as: fixture.identity, store: fixture.store
        )
        #expect(!afterRoom.isError)
        #expect(says.targets == [running.title, "spare"])
    }

    @Test("the stored name is what crosses the seam, whatever case the caller wrote")
    func theResolvedNameIsWhatCrosses() async throws {
        let fixture = try await self.fixture("crew-say-case")
        try await member(fixture, "read-the-cascade")
        let says = Says()

        let result = await says.tool().call(
            request("agent_say", [
                "to": .string("READ-THE-CASCADE"), "message": .string("Stop at the parser."),
            ]),
            as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        #expect(says.targets == ["read-the-cascade"])
    }

    @Test("an orchestrator sees the agents it started, with what each is doing")
    func listingYourOwnCrew() async throws {
        let fixture = try await self.fixture("crew-list")
        try await member(fixture, "tests", state: .running)
        try await member(fixture, "docs", state: .idle)

        let result = await AgentListTool().call(
            request("agent_list"), as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        let json = try answer(result)
        #expect(json["you"]?.stringValue == "Chat")
        #expect(json["running"]?.intValue == 1)
        #expect(json["running_limit"]?.intValue == Crew.ceiling)

        let crew = try #require(json["crew"]?.arrayValue)
        #expect(crew.compactMap { $0["name"]?.stringValue } == ["tests", "docs"])
        #expect(crew.first?["running"]?.boolValue == true)
        #expect(crew.first?["state"]?.stringValue == "running")
        #expect(crew.last?["running"]?.boolValue == false)
        #expect(crew.allSatisfy { $0["is_you"]?.boolValue == false })
        #expect(json["orchestrator"] == nil)
    }

    @Test("a subagent sees the whole crew, itself included, and who is above it")
    func listingFromInsideTheCrew() async throws {
        let fixture = try await self.fixture("crew-list-inside")
        let crewMember = try await member(fixture, "tests", state: .running)
        try await member(fixture, "docs")

        let result = await AgentListTool().call(
            request("agent_list"), as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(!result.isError)
        let json = try answer(result)
        #expect(json["you"]?.stringValue == "tests")
        #expect(json["orchestrator"]?.stringValue == "Chat")

        let crew = try #require(json["crew"]?.arrayValue)
        #expect(crew.compactMap { $0["name"]?.stringValue } == ["tests", "docs"])
        #expect(crew.first?["is_you"]?.boolValue == true)
        #expect(crew.last?["is_you"]?.boolValue == false)
        #expect(result.text.contains("same branch"))
        #expect(!result.text.contains(Crew.tidyHint))
    }

    @Test("an empty crew answers with a note saying how one begins")
    func listingAnEmptyCrew() async throws {
        let fixture = try await self.fixture("crew-list-empty")

        let result = await AgentListTool().call(
            request("agent_list"), as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        let json = try answer(result)
        #expect(json["crew"]?.arrayValue?.isEmpty == true)
        #expect(json["running"]?.intValue == 0)
        #expect(result.text.contains("agent_start"))
    }

    @Test("a full workspace says the next start will be refused")
    func listingSaysWhenTheSlotsAreGone() async throws {
        let fixture = try await self.fixture("crew-list-full")
        try await fillToCeiling(fixture)

        let result = await AgentListTool().call(
            request("agent_list"), as: fixture.identity, store: fixture.store
        )

        #expect(json(result, "running")?.intValue == Crew.ceiling)
        #expect(result.text.contains("agent_start will be refused"))
        #expect(!result.text.contains(Crew.tidyHint))
    }

    @Test("a crew with finished members is counted and told to finish with them")
    func listingCountsWhatThereIsToTidy() async throws {
        let fixture = try await self.fixture("crew-list-finished")
        try await member(fixture, "one", state: .running)
        try await member(fixture, "two")
        try await member(fixture, "three", state: .failed)

        let result = await AgentListTool().call(
            request("agent_list"), as: fixture.identity, store: fixture.store
        )

        #expect(result.text.contains("3 subagents: 1 running, 2 finished"))
        #expect(result.text.contains(Crew.tidyHint))
    }

    private func json(_ result: BridgeToolResult, _ key: String) -> JSONValue? {
        JSONValue.parse(result.text)?[key]
    }

    @Test("an orchestrator stops one of its own by name")
    func stoppingYourOwn() async throws {
        let fixture = try await self.fixture("crew-stop")
        try await member(fixture, "tests", state: .running)
        let stops = Stops()

        let result = await stops.tool().call(
            request("agent_stop", ["name": .string(" tests ")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(!result.isError)
        #expect(stops.names == ["tests"])
        #expect(stops.callers == [fixture.orchestrator.id])
    }

    @Test("an agent cannot stop another chat's subagent")
    func stoppingAcrossChats() async throws {
        let fixture = try await self.fixture("crew-stop-across")
        let sibling = try await fixture.store.upsert(Session(
            workspaceID: fixture.workspace.id, title: "Second chat"
        ))
        try await member(fixture, "theirs", of: sibling, state: .running)
        let stops = Stops()

        let result = await stops.tool().call(
            request("agent_stop", ["name": .string("theirs")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("started no subagents"))
        #expect(stops.names.isEmpty)
    }

    @Test("a subagent cannot stop anybody, because it started nobody")
    func aSubagentCannotStop() async throws {
        let fixture = try await self.fixture("crew-stop-subagent")
        let crewMember = try await member(fixture, "tests")
        try await member(fixture, "docs", state: .running)
        let stops = Stops()

        let result = await stops.tool().call(
            request("agent_stop", ["name": .string("docs")]),
            as: fixture.identity(of: crewMember), store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("you are a subagent"))
        #expect(stops.names.isEmpty)
    }

    @Test("a name with nothing behind it is refused with the names there are")
    func stoppingAnUnknownName() async throws {
        let fixture = try await self.fixture("crew-stop-unknown")
        try await member(fixture, "tests")
        let stops = Stops()

        let result = await stops.tool().call(
            request("agent_stop", ["name": .string("typo")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("no subagent called 'typo'"))
        #expect(result.text.contains("tests"))
        #expect(stops.names.isEmpty)
    }

    @Test("a missing name is refused with where to find one")
    func stoppingWithNoName() async throws {
        let fixture = try await self.fixture("crew-stop-noname")
        let stops = Stops()

        let result = await stops.tool().call(
            request("agent_stop", ["name": .string("  ")]),
            as: fixture.identity, store: fixture.store
        )

        #expect(result.isError)
        #expect(result.text.contains("agent_list"))
        #expect(stops.names.isEmpty)
    }

    @Test("an exact name wins, case is ignored after it, and a pair that differ only in case is refused")
    func theLookup() {
        let workspace = WorkspaceID("w")
        let lower = Session(workspaceID: workspace, parentSessionID: SessionID("p"), title: "tests")
        let upper = Session(workspaceID: workspace, parentSessionID: SessionID("p"), title: "Tests")
        let other = Session(workspaceID: workspace, parentSessionID: SessionID("p"), title: "docs")

        #expect(CrewLookup.find("tests", among: [lower, other]) == .found(lower))
        #expect(CrewLookup.find("TESTS", among: [lower, other]) == .found(lower))
        #expect(CrewLookup.find("  tests\n", among: [lower, other]) == .found(lower))
        #expect(CrewLookup.find("Tests", among: [lower, upper]) == .found(upper))
        #expect(CrewLookup.find("tests", among: [lower, upper]) == .found(lower))
        #expect(CrewLookup.find("TESTS", among: [lower, upper]) == .ambiguous([lower, upper]))
        #expect(CrewLookup.find("nothing", among: [lower, other]) == .unknown)
        #expect(CrewLookup.find("   ", among: [lower, other]) == .unknown)
    }
}
