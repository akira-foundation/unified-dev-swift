import Core
import Testing

@MainActor
@Suite("What a wait reads off a page", .serialized)
struct BrowserWaitingTests {
    @Test("a page that has finished loading says so")
    func aSettledPageIsSettled() async throws {
        let page = try await BrowserPageFixture.body("<p>Here.</p>")

        #expect(try await page.reading(.load) == .met)
    }

    @Test("a wait for words settles when the page is showing them and not before")
    func waitingForWords() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="slot"></p>
            <button onclick="slot.textContent = 'Saved the form'">Save</button>
            """
        )
        try await page.snapshot()

        #expect(try await page.reading(.text("Saved")) == .waiting)
        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.reading(.text("Saved")) == .met)
    }

    @Test("a wait for words to go settles when they have gone and not before")
    func waitingForWordsToGo() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="slot">Loading the page</p>
            <button onclick="slot.remove()">Finish</button>
            """
        )
        try await page.snapshot()

        #expect(try await page.reading(.gone("Loading")) == .waiting)
        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.reading(.gone("Loading")) == .met)
    }

    @Test("words a reader cannot see do not settle a wait, and do not keep one waiting")
    func onlyWhatIsShownCounts() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p style="display: none">Saved the form</p>
            <div hidden>Loading the page</div>
            """
        )

        #expect(try await page.reading(.text("Saved")) == .waiting)
        #expect(try await page.reading(.gone("Loading")) == .met)
    }

    @Test("a wait reads the words the owner would read, and not the markup behind them")
    func theMarkupIsNotTheWords() async throws {
        let page = try await BrowserPageFixture.body(
            #"<p class="Saved" data-state="Saved">Still working</p>"#
        )

        #expect(try await page.reading(.text("Saved")) == .waiting)
        #expect(try await page.reading(.text("Still working")) == .met)
    }

    @Test("a wait for words that span two elements reads them as the page lays them out")
    func wordsAcrossElementsReadAsOneLine() async throws {
        let page = try await BrowserPageFixture.body(
            "<p>Saved <strong>the form</strong></p>"
        )

        #expect(try await page.reading(.text("Saved the form")) == .met)
    }

    @Test("the three waits read the same page differently, which is why there are three")
    func thethreeWaitsAreThreeAnswers() async throws {
        let page = try await BrowserPageFixture.body("<p>Saved the form</p>")

        #expect(try await page.reading(.load) == .met)
        #expect(try await page.reading(.text("Saved")) == .met)
        #expect(try await page.reading(.gone("Saved")) == .waiting)
    }
}
