import Testing
@testable import Core

@Suite("Asking for a pane")
struct PaneToolTests {
    private func read(
        kind: String? = "terminal", url: String? = nil, focus: JSONValue? = nil,
        title: String? = nil
    ) -> PaneOrderReading {
        PaneOrder.parse(kind: kind, url: url, focus: focus, title: title, tool: "pane_open")
    }

    @Test("every kind the menu offers is a kind a tool accepts")
    func everyMenuKindIsAWireKind() {
        for kind in PaneKind.allCases {
            #expect(read(kind: kind.rawValue) == .order(PaneOrder(kind: kind)))
        }
    }

    @Test("an unknown kind is refused with the list of real ones")
    func anUnknownKindListsTheRealOnes() {
        guard case .refused(let sentence) = read(kind: "editor") else {
            Issue.record("expected a refusal"); return
        }
        #expect(sentence.contains("'editor'"))
        for kind in PaneKind.allCases {
            #expect(sentence.contains("'\(kind.rawValue)'"))
        }
    }

    @Test("a missing kind says which argument is missing and what it takes")
    func aMissingKindSaysSo() {
        for missing in [nil, "", "   "] as [String?] {
            guard case .refused(let sentence) = read(kind: missing) else {
                Issue.record("expected a refusal for \(String(describing: missing))"); return
            }
            #expect(sentence.contains("'kind'"))
            #expect(sentence.contains("pane_open"))
        }
    }

    @Test("surrounding whitespace is not a different kind")
    func whitespaceIsTrimmed() {
        #expect(read(kind: "  browser ") == .order(PaneOrder(kind: .browser)))
    }

    @Test("a browser takes a url, and keeps it")
    func aBrowserKeepsItsURL() {
        #expect(
            read(kind: "browser", url: "https://unified-dev.akira-io.com")
                == .order(PaneOrder(kind: .browser, url: "https://unified-dev.akira-io.com"))
        )
    }

    @Test("a browser without a url is fine")
    func aBrowserNeedsNoURL() {
        #expect(read(kind: "browser") == .order(PaneOrder(kind: .browser)))
        #expect(read(kind: "browser", url: "  ") == .order(PaneOrder(kind: .browser)))
    }

    @Test("a url on anything but a browser is refused rather than dropped")
    func aURLElsewhereIsRefused() {
        for kind in PaneKind.allCases where kind != .browser {
            guard case .refused(let sentence) = read(kind: kind.rawValue, url: "https://x.test")
            else {
                Issue.record("expected a refusal for \(kind)"); return
            }
            #expect(sentence.contains("browser"))
        }
    }

    @Test("a browser pane opens http and https, and refuses anything else")
    func refusesSchemesTheOwnerDidNotChoose() {
        for url in ["file:///Users/freek/.ssh/id_rsa", "ftp://example.com", "unifieddev://open"] {
            let outcome = PaneOrder.parse(
                kind: "browser", url: url, focus: nil, tool: "pane_open"
            )
            guard case .refused(let why) = outcome else {
                Issue.record("\(url) was not refused")
                continue
            }
            #expect(why.contains("http and https"))
        }

        for url in ["http://localhost:3000", "https://unified-dev.akira-io.com"] {
            guard case .order(let order) = PaneOrder.parse(
                kind: "browser", url: url, focus: nil, tool: "pane_open"
            ) else {
                Issue.record("\(url) was refused")
                continue
            }
            #expect(order.url == url)
        }
    }

    @Test("focus defaults to yes")
    func focusDefaultsToYes() {
        guard case .order(let order) = read() else { Issue.record("expected an order"); return }
        #expect(order.focus)
    }

    @Test("focus can be turned off, and only by a boolean")
    func focusIsABoolean() {
        #expect(read(focus: .bool(false)) == .order(PaneOrder(kind: .terminal, focus: false)))
        #expect(read(focus: .bool(true)) == .order(PaneOrder(kind: .terminal, focus: true)))
        #expect(read(focus: .null) == .order(PaneOrder(kind: .terminal, focus: true)))

        guard case .refused(let sentence) = read(focus: .string("yes")) else {
            Issue.record("expected a refusal"); return
        }
        #expect(sentence.contains("'focus'"))
    }

    @Test("what the model is told says whether the reader is looking at it")
    func theConfirmationSaysWhereItWent() {
        #expect(PaneOrder(kind: .terminal).confirmation.contains("front"))
        #expect(PaneOrder(kind: .terminal, focus: false).confirmation.contains("background"))
        #expect(
            PaneOrder(kind: .browser, url: "https://unified-dev.akira-io.com").confirmation
                .contains("https://unified-dev.akira-io.com")
        )
    }

    @Test("a name given for a tab arrives as the name of the tab")
    func aTitleSurvives() {
        #expect(
            read(title: "Build log")
                == .order(PaneOrder(kind: .terminal, title: "Build log"))
        )
        #expect(
            read(title: "  Build log  ")
                == .order(PaneOrder(kind: .terminal, title: "Build log"))
        )
    }

    @Test("a blank name is no name rather than a blank tab")
    func aBlankTitleIsNoTitle() {
        for blank in [nil, "", "   ", "\n"] as [String?] {
            #expect(read(title: blank) == .order(PaneOrder(kind: .terminal)))
        }
    }

    @Test("what the model is told names the tab when there is a name")
    func theConfirmationNamesTheTab() {
        let named = PaneOrder(kind: .terminal, title: "Build log").confirmation
        #expect(named.contains("'Build log'"))
        #expect(!PaneOrder(kind: .terminal).confirmation.contains("called"))
    }

    @Test("a rename takes a name, and a kind is optional")
    func aRenameTakesANameAndOptionallyAKind() throws {
        #expect(
            try PaneRenameTool.parse(title: "  Docs ", kind: nil).get()
                == PaneRenameOrder(title: "Docs")
        )
        #expect(
            try PaneRenameTool.parse(title: "Docs", kind: " browser ").get()
                == PaneRenameOrder(title: "Docs", kind: .browser)
        )
    }

    @Test("a rename with no name is refused rather than blanking the tab")
    func aRenameNeedsAName() {
        for blank in [nil, "", "   "] as [String?] {
            guard case .failure(let refusal) = PaneRenameTool.parse(title: blank, kind: nil) else {
                Issue.record("expected a refusal for \(String(describing: blank))"); return
            }
            #expect(refusal.sentence.contains("'title'"))
        }
    }

    @Test("a rename of a kind that does not exist lists the ones that do")
    func aRenameRefusesAnUnknownKind() {
        guard case .failure(let refusal) = PaneRenameTool.parse(title: "Docs", kind: "editor")
        else { Issue.record("expected a refusal"); return }
        #expect(refusal.sentence.contains("'editor'"))
        for kind in PaneKind.allCases {
            #expect(refusal.sentence.contains("'\(kind.rawValue)'"))
        }
    }

    @Test("renaming asks for a title and offers the kinds, and nothing else")
    func renamingSpeaksTheSameVocabulary() {
        let rename = PaneRenameTool { _, _, _ in .opened("") }
        guard case .object(let schema) = rename.tool.inputSchema,
              case .object(let properties)? = schema["properties"]
        else { Issue.record("no schema"); return }
        #expect(Set(properties.keys) == ["title", "kind"])
        #expect(schema["required"] == .array([.string("title")]))
    }

    @Test("opening and splitting both accept a title")
    func bothOpenersTakeATitle() {
        for tool in [PaneOpenTool { _, _ in .opened("") }.tool,
                     PaneSplitTool { _, _, _, _ in .opened("") }.tool] {
            guard case .object(let schema) = tool.inputSchema,
                  case .object(let properties)? = schema["properties"]
            else { Issue.record("no schema for \(tool.name)"); return }
            #expect(properties["title"] != nil)
            #expect(tool.description.contains("title"))
        }
    }

    @Test("beside is side by side, below is stacked, and beside is the default")
    func theDirectionIsNamedForTheReader() throws {
        #expect(try PaneSplitTool.axis(named: "beside").get() == .horizontal)
        #expect(try PaneSplitTool.axis(named: "below").get() == .vertical)
        #expect(try PaneSplitTool.axis(named: nil).get() == .horizontal)
        #expect(try PaneSplitTool.axis(named: "  BESIDE ").get() == .horizontal)
    }

    @Test("an unknown direction is refused with the two that work")
    func anUnknownDirectionIsRefused() {
        guard case .failure(let refusal) = PaneSplitTool.axis(named: "diagonally") else {
            Issue.record("expected a refusal"); return
        }
        #expect(refusal.sentence.contains("beside"))
        #expect(refusal.sentence.contains("below"))
    }

    @Test("only a parent can open, split, close or rename panes")
    func onlyAParentCanTouchPanes() {
        let open = PaneOpenTool { _, _ in .opened("") }
        let split = PaneSplitTool { _, _, _, _ in .opened("") }
        let close = PaneCloseTool { _, _ in .opened("") }
        let rename = PaneRenameTool { _, _, _ in .opened("") }
        for roles in [open.roles, split.roles, close.roles, rename.roles] {
            #expect(roles == [.parent])
        }
    }

    @Test("no workspace scoped tool is offered to a connection standing in no workspace")
    func ownerIsOfferedNothingItCannotUse() {
        #expect(BridgeIdentity.owner.workspaceID == nil)
    }

    @Test("closing takes the same kinds opening does, and none of its own")
    func closingSpeaksTheSameVocabulary() {
        let close = PaneCloseTool { _, _ in .opened("") }
        guard case .object(let schema) = close.tool.inputSchema,
              case .object(let properties)? = schema["properties"]
        else { Issue.record("no schema"); return }
        #expect(Set(properties.keys) == ["kind"])
        #expect(schema["required"] == nil)
    }

    @Test("both are Unified Dev's own tools and need no confirmation")
    func bothAreSelfApproved() {
        #expect(BridgeToolApproval.selfApproved.contains("pane_open"))
        #expect(BridgeToolApproval.selfApproved.contains("pane_split"))
        #expect(BridgeToolApproval.selfApproved.contains("pane_close"))
        #expect(BridgeToolApproval.selfApproved.contains("pane_rename"))
        #expect(!BridgeToolApproval.selfApproved.contains("workspace_merge"))
    }
}

@Suite("Unified Dev's own tools, as a reader meets them")
struct BridgePresentationTests {
    private func present(_ tool: String) -> ToolPresentation {
        ToolPresenter.present(
            name: "mcp__\(BridgeRegistration.serverName)__\(tool)", input: .object([:])
        )
    }

    @Test("the transport does not appear in the row")
    func theTransportIsNotTheLabel() {
        let row = present("pane_open")
        #expect(row.label == "Unified Dev: pane open")
        #expect(!row.label.contains("bridge"))
        #expect(!row.label.contains("workspace-bridge"))
    }

    @Test("Unified Dev's own tools do not wear the extension glyph")
    func unifieddevHasItsOwnGlyph() {
        #expect(present("pane_open").glyph != "puzzlepiece.extension")
        #expect(present("workspace_start").glyph != "puzzlepiece.extension")
    }

    @Test("another server is still named after itself")
    func anotherServerKeepsItsName() {
        let row = ToolPresenter.present(name: "mcp__linear__create_issue", input: .object([:]))
        #expect(row.label == "linear: create issue")
        #expect(row.glyph == "puzzlepiece.extension")
    }
}
