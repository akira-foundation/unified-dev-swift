@testable import Core
import Testing

@MainActor
@Suite("What the outline script can see on a page", .serialized)
struct BrowserDrawingTests {
    @Test("an element the page hides is not listed, however it hides it", arguments: [
        "<button hidden>Hidden</button>",
        "<button style=\"display: none\">Hidden</button>",
        "<button style=\"visibility: hidden\">Hidden</button>",
        "<div style=\"display: none\"><button>Hidden</button></div>",
        "<div hidden><span><button>Hidden</button></span></div>",
    ])
    func hiddenElementsStayOut(markup: String) async throws {
        let page = try await BrowserPageFixture.body(
            "<button>Visible</button>\(markup)"
        )
        let survey = try await page.survey()

        #expect(survey.names == ["Visible"])
        #expect(survey.total == 1)
    }

    @Test("a page that says an element is hidden is believed, whatever its own styling says")
    func theHiddenAttributeIsBelieved() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <button>Visible</button>
            <button hidden>Drawn but hidden</button>
            """,
            head: "<style>[hidden] { display: block }</style>"
        )
        let survey = try await page.survey()

        #expect(survey.names == ["Visible"])
    }

    @Test("a control with a layout box of no size is kept, because its label is what shows")
    func sizeIsNotTheFilter() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <label for="pick">Choose a file</label>
            <input id="pick" type="file" style="width: 0; height: 0; padding: 0; border: 0">
            <input aria-label="Screen reader only"
                   style="position: absolute; width: 1px; height: 1px; clip: rect(0 0 0 0)">
            """
        )
        let survey = try await page.survey()

        #expect(survey.names == ["Choose a file", "Screen reader only"])
    }

    @Test("a hidden element takes no reference, so every later one still points at itself")
    func theRegisterSkipsWhatTheListingSkips() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <button onclick="log.textContent += 'first '">First</button>
            <button hidden onclick="log.textContent += 'buried '">Buried</button>
            <button onclick="log.textContent += 'second '">Second</button>
            """
        )
        let survey = try await page.survey()
        #expect(survey.names == ["First", "Second"])

        let answer = try await page.answer(.clicking(2))
        #expect(answer == ["done", "Second"])
        #expect(try await page.visibleText().contains("second"))
        #expect(!(try await page.visibleText().contains("buried")))
    }

    @Test("the selectors reach what a reader could use and nothing else")
    func theSelectorListIsTheOneThatRuns() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <a href="/go">Linked</a>
            <a>Anchor</a>
            <button>Button</button>
            <input type="text" aria-label="Field">
            <select aria-label="Choice"><option>One</option></select>
            <textarea aria-label="Area"></textarea>
            <details><summary>Fold</summary>Body</details>
            <div role="button">Roled</div>
            <div contenteditable="true" aria-label="Editable"></div>
            <div>Plain</div>
            <span>Span</span>
            <p>Paragraph</p>
            """
        )
        let survey = try await page.survey()

        #expect(
            survey.names == [
                "Linked", "Button", "Field", "Choice", "Area", "Fold", "Roled", "Editable",
            ]
        )
    }

    @Test("an anchor with no href is not a link, and one with an empty href is")
    func anAnchorNeedsAnHref() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <a>Nowhere</a>
            <a href="">Here</a>
            <a name="old">Named</a>
            """
        )
        let survey = try await page.survey()

        #expect(survey.names == ["Here"])
    }

    @Test("the register never hands out more references than the listing printed")
    func theLimitHoldsOnBothSides() async throws {
        let extra = 5
        let buttons = (1...(BrowserPageOutline.elementLimit + extra))
            .map { "<button>b\($0)</button>" }
            .joined()
        let page = try await BrowserPageFixture.body(buttons)
        let survey = try await page.survey()

        #expect(survey.elements.count == BrowserPageOutline.elementLimit)
        #expect(survey.total == BrowserPageOutline.elementLimit + extra)
        #expect(survey.names.last == "b\(BrowserPageOutline.elementLimit)")

        let listing = try await page.listing()
        #expect(
            listing.contains(
                "the first \(BrowserPageOutline.elementLimit) of "
                    + "\(BrowserPageOutline.elementLimit + extra) elements"
            )
        )
    }

    @Test("nothing past the limit is in the register either, so a reference to it is gone")
    func theRegisterStopsWhereTheListingStops() async throws {
        let extra = 5
        let buttons = (1...(BrowserPageOutline.elementLimit + extra))
            .map { "<button>b\($0)</button>" }
            .joined()
        let page = try await BrowserPageFixture.body(buttons)
        try await page.snapshot()

        let last = BrowserPageOutline.elementLimit
        #expect(try await page.answer(.clicking(last)) == ["done", "b\(last)"])
        #expect(try await page.answer(.clicking(last + 1)) == ["gone"])
        #expect(try await page.answer(.clicking(last + extra)) == ["gone"])
    }

    @Test("a field the page keeps off the screen is not listed, and its value is not read")
    func aHiddenFieldIsNeitherListedNorRead() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <input type="hidden" name="csrf" value="a-token-the-agent-must-not-see">
            <button>Send</button>
            """
        )
        let survey = try await page.survey()

        #expect(survey.names == ["Send"])
        #expect(!(try await page.listing().contains("a-token-the-agent-must-not-see")))
    }

    @Test("a box says whether it is ticked, and never the value it would submit")
    func aBoxReportsItsTick() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <input type="checkbox" value="yes" checked aria-label="Agreed">
            <input type="checkbox" value="no" aria-label="Refused">
            <input type="radio" name="pick" value="one" checked aria-label="One">
            <input type="radio" name="pick" value="two" aria-label="Two">
            """
        )
        let survey = try await page.survey()

        #expect(survey.elements.map(\.isChecked) == [true, false, true, false])
        #expect(survey.elements.map(\.value) == [nil, nil, nil, nil])
        #expect(survey.elements.allSatisfy { $0.valueLength == 0 })
        #expect(try await page.listing().contains("checkbox \"Agreed\" [e1] (checked)"))
        #expect(try await page.listing().contains("checkbox \"Refused\" [e2] (not checked)"))
    }

    @Test("a thing the page only says is ticked is reported as ticked")
    func aSpokenTickIsATick() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <div role="switch" aria-checked="true" aria-label="Spoken on">Spoken on</div>
            <div role="switch" aria-checked="false" aria-label="Spoken off">Spoken off</div>
            <div role="switch" aria-label="Says nothing">Says nothing</div>
            """
        )
        let survey = try await page.survey()

        #expect(survey.elements.map(\.isChecked) == [true, false, nil])
    }

    @Test("the value a snapshot reports is a field's, and nothing else is given one")
    func onlyAFieldCarriesAValue() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <input type="text" value="written" aria-label="Field">
            <input type="submit" value="Send">
            <select aria-label="Choice"><option>One</option><option>Two</option></select>
            <button value="pressed">Press</button>
            <a href="/go">Link</a>
            <div role="button">Roled</div>
            """
        )
        let survey = try await page.survey()

        #expect(survey.elements.map(\.value) == ["written", "Send", "One", "pressed", nil, nil])
    }

    @Test("a page with nothing to point at says so rather than listing the body")
    func anEmptyPageIsAnEmptyListing() async throws {
        let page = try await BrowserPageFixture.body("<p>Words and nothing else.</p>")
        let survey = try await page.survey()

        #expect(survey.elements.isEmpty)
        #expect(survey.total == 0)
        #expect(try await page.listing().contains("nothing on it an agent can point at"))
    }
}
