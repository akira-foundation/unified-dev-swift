import Testing
@testable import Core

@Suite("Whether a workspace may be started")
struct WorkspaceStartPlanTests {
    @Test("a chat needs words")
    func chatNeedsWords() {
        #expect(!WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "", hasCheckout: false,
            isChatWorkspace: true, isBusy: false
        ))
        #expect(WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "Fix the login flow", hasCheckout: false,
            isChatWorkspace: true, isBusy: false
        ))
    }

    @Test("whitespace is not words")
    func whitespaceIsNotWords() {
        #expect(!WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "   \n\t ", hasCheckout: false,
            isChatWorkspace: true, isBusy: false
        ))
    }

    @Test("a terminal needs nothing written at all")
    func terminalNeedsNothing() {
        #expect(WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "", hasCheckout: false,
            isChatWorkspace: false, isBusy: false
        ))
    }

    @Test("a checkout needs nothing written, because the pull request brought its own name")
    func checkoutNeedsNothing() {
        #expect(WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "", hasCheckout: true,
            isChatWorkspace: true, isBusy: false
        ))
    }

    @Test("no project, no start, whatever else is true")
    func projectIsRequired() {
        #expect(!WorkspaceStartPlan.canStart(
            hasProject: false, prompt: "Fix the login flow", hasCheckout: true,
            isChatWorkspace: false, isBusy: false
        ))
    }

    @Test("a create already in flight blocks every route")
    func busyBlocksEveryRoute() {
        #expect(!WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "Fix the login flow", hasCheckout: false,
            isChatWorkspace: true, isBusy: true
        ))
        #expect(!WorkspaceStartPlan.canStart(
            hasProject: true, prompt: "", hasCheckout: false,
            isChatWorkspace: false, isBusy: true
        ))
    }

    @Test("a typed branch names a terminal workspace")
    func typedBranchNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: "spike/perf", claimedSea: "Coral Sea"
        ) == "spike/perf")
    }

    @Test("otherwise the sea does")
    func seaNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: nil, claimedSea: "Coral Sea"
        ) == "Coral Sea")
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: "", claimedSea: "Coral Sea"
        ) == "Coral Sea")
    }

    @Test("with neither, nothing is claimed to be the name")
    func neitherNames() {
        #expect(WorkspaceStartPlan.terminalName(
            userSuppliedBranch: nil, claimedSea: nil
        ) == nil)
    }
}

@Suite("Crossing between chat and terminal")
struct WorkspaceModeCrossingTests {
    @Test("a sentence becomes the name it was always going to become")
    func sentenceBecomesTheName() {
        #expect(WorkspaceStartPlan.carriedName(
            prompt: "Fix the flaky worktree test", currentName: ""
        ) == "Fix the flaky worktree test")
    }

    @Test("a long sentence is cut where the name would have been cut")
    func longSentenceIsCut() {
        let prompt = String(repeating: "alpha ", count: 40)
        #expect(WorkspaceStartPlan.carriedName(prompt: prompt, currentName: "")
                == Git.title(from: prompt))
    }

    @Test("only the first line, because that is what names a workspace")
    func firstLineOnly() {
        #expect(WorkspaceStartPlan.carriedName(
            prompt: "Rebase onto main\n\nThen fix the conflicts", currentName: ""
        ) == "Rebase onto main")
    }

    @Test("a name already typed is never overwritten")
    func typedNameWins() {
        #expect(WorkspaceStartPlan.carriedName(
            prompt: "Fix the flaky worktree test", currentName: "spike"
        ) == "spike")
    }

    @Test("an empty box carries an empty name, not a placeholder")
    func emptyStaysEmpty() {
        #expect(WorkspaceStartPlan.carriedName(prompt: "", currentName: "").isEmpty)
        #expect(WorkspaceStartPlan.carriedName(prompt: "  \n\t ", currentName: "").isEmpty)
    }

    @Test("a name typed in terminal mode comes back as the prompt")
    func nameComesBack() {
        #expect(WorkspaceStartPlan.carriedPrompt(
            name: "Fix the flaky worktree test", currentPrompt: ""
        ) == "Fix the flaky worktree test")
    }

    @Test("a draft already in the box wins")
    func draftWins() {
        #expect(WorkspaceStartPlan.carriedPrompt(
            name: "spike", currentPrompt: "Rebase onto main"
        ) == "Rebase onto main")
    }

    @Test("a round trip loses nothing and invents nothing")
    func roundTrip() {
        let written = "Fix the flaky worktree test"
        let name = WorkspaceStartPlan.carriedName(prompt: written, currentName: "")
        #expect(WorkspaceStartPlan.carriedPrompt(name: name, currentPrompt: written) == written)
    }
}

@Suite("What the create window opens on")
struct WorkspaceStartModeTests {
    @Test("a fresh install opens on chat")
    func freshInstallIsChat() {
        #expect(WorkspaceStartMode.remembered(raw: nil) == .chat)
    }

    @Test("the last choice is what it opens on")
    func lastChoiceWins() {
        #expect(WorkspaceStartMode.remembered(raw: "terminal") == .terminal)
        #expect(WorkspaceStartMode.remembered(raw: "chat") == .chat)
        #expect(WorkspaceStartMode.remembered(raw: "browser") == .browser)
    }

    @Test("anything unreadable is a fresh install")
    func unreadableIsFresh() {
        #expect(WorkspaceStartMode.remembered(raw: "shell") == .chat)
        #expect(WorkspaceStartMode.remembered(raw: "") == .chat)
    }

    @Test("chat and CLI starts run agents")
    func agentStartsRunAgents() {
        #expect(WorkspaceStartMode.chat.runsAnAgent)
        #expect(WorkspaceStartMode.claudeCLI.runsAnAgent)
        #expect(WorkspaceStartMode.codexCLI.runsAnAgent)
        #expect(!WorkspaceStartMode.terminal.runsAnAgent)
        #expect(!WorkspaceStartMode.browser.runsAnAgent)
    }

    @Test("CLI starts retain their backend and agent tab")
    func cliStartsUseAgentTabs() {
        #expect(WorkspaceStartMode.claudeCLI.cliAgentKind == .claudeCode)
        #expect(WorkspaceStartMode.codexCLI.cliAgentKind == .codex)
        for mode in [WorkspaceStartMode.claudeCLI, .codexCLI] {
            #expect(mode.pane == .chat)
            #expect(WorkspaceStartMode.remembered(raw: mode.rawValue) == mode)
        }
        #expect(WorkspaceStartMode.chat.cliAgentKind == nil)
        #expect(WorkspaceStartMode.terminal.cliAgentKind == nil)
    }

    @Test("only the segment that runs an agent says more than its tab's name")
    func onlyChatSaysMoreThanItsName() {
        #expect(WorkspaceStartMode.chat.pickerLabel == "Chat with an agent")
        #expect(WorkspaceStartMode.terminal.pickerLabel == WorkspaceStartMode.terminal.label)
        #expect(WorkspaceStartMode.browser.pickerLabel == WorkspaceStartMode.browser.label)
    }

    @Test("every label is one word the heading can borrow")
    func labelsAreNounsTheHeadingCanUse() {
        for mode in [WorkspaceStartMode.chat, .terminal, .browser] {
            #expect(!mode.label.contains(" "))
        }
    }
}

@Suite("What a mode with no agent says about itself")
struct StartNoteTests {
    @Test("an empty field promises a name without explaining where it comes from")
    func emptyFieldPromisesAName() {
        let note = WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: false, name: "")
        #expect(note.contains("Leave it empty and Unified Dev names it for you"))
    }

    @Test("a filled field says what it is about to name")
    func filledFieldSaysWhatItNames() {
        let note = WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: false, name: "spike")
        #expect(note.contains("This names the workspace and its branch"))
    }

    @Test("whitespace is an empty field")
    func whitespaceIsEmpty() {
        #expect(WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: false, name: "  \n ")
                == WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: false, name: ""))
    }

    @Test("a checkout says what the workspace will be instead")
    func checkoutSaysWhatItWillBe() {
        let note = WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: true, name: "")
        #expect(note.contains("a shell opens in the worktree"))
        #expect(!note.contains("Leave it empty"))
    }

    @Test("a browser checkout does not promise a shell")
    func browserCheckoutOpensABrowser() {
        let note = WorkspaceStartPlan.startNote(mode: .browser, hasCheckout: true, name: "")
        #expect(note.contains(WorkspaceStartMode.browser.openingSentence))
        #expect(!note.contains("shell"))
    }

    @Test("without a checkout the two agentless modes say the same thing")
    func agentlessModesAgreeWithoutACheckout() {
        for name in ["", "spike"] {
            #expect(WorkspaceStartPlan.startNote(mode: .terminal, hasCheckout: false, name: name)
                    == WorkspaceStartPlan.startNote(mode: .browser, hasCheckout: false, name: name))
        }
    }

    @Test("every sentence says that nothing is sent to an agent")
    func everySentenceSaysNoAgent() {
        for mode in [WorkspaceStartMode.terminal, .browser] {
            for (hasCheckout, name) in [(true, ""), (true, "spike"), (false, ""), (false, "spike")] {
                let note = WorkspaceStartPlan.startNote(mode: mode, hasCheckout: hasCheckout, name: name)
                #expect(note.hasSuffix("Nothing is sent to an agent."))
            }
        }
    }

    @Test("a name that was settled wins over everything")
    func settledNameWins() {
        #expect(WorkspaceStartPlan.name(
            supplied: "Harbour", checkout: nil, prompt: "Fix the login flow"
        ) == "Harbour")
        #expect(WorkspaceStartPlan.name(
            supplied: "Harbour",
            checkout: .branch(ExistingBranch(name: "feature/x", isLocal: true)),
            prompt: ""
        ) == "Harbour")
    }

    @Test("an empty name is no name")
    func emptyNameIsNoName() {
        #expect(WorkspaceStartPlan.name(
            supplied: "", checkout: nil, prompt: "Fix the login flow"
        ) == "Fix the login flow")
    }

    @Test("a checkout brings its own name")
    func checkoutBringsItsOwn() {
        #expect(WorkspaceStartPlan.name(
            supplied: nil,
            checkout: .branch(ExistingBranch(name: "feature/x", isLocal: true)),
            prompt: "ignored"
        ) == "feature/x")
    }

    @Test("nothing settled falls back to the task, and an empty task still has a name")
    func fallsBackToTheTask() {
        #expect(WorkspaceStartPlan.name(
            supplied: nil, checkout: nil, prompt: "Fix the login flow"
        ) == "Fix the login flow")
        #expect(!WorkspaceStartPlan.name(supplied: nil, checkout: nil, prompt: "").isEmpty)
    }

    @Test("no sentence names the mechanism behind the name")
    func nothingNamesTheMechanism() {
        let forbidden = ["sea", "ocean"]
        for mode in [WorkspaceStartMode.terminal, .browser] {
            for (hasCheckout, name) in [(true, ""), (true, "spike"), (false, ""), (false, "spike")] {
                let note = WorkspaceStartPlan
                    .startNote(mode: mode, hasCheckout: hasCheckout, name: name)
                    .lowercased()
                for word in forbidden {
                    #expect(!note.contains(word), "\(note) names \(word)")
                }
            }
        }
    }
}
