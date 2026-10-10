import Core
import Testing

@MainActor
@Suite("What a fill writes, what it reads back and what it refuses", .serialized)
struct BrowserFillingTests {
    @Test("a fill writes the text and reports what the field is holding afterwards")
    func aFillReportsTheField() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" aria-label="Your name">"#
        )
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "Ana"))

        #expect(answer == ["done", "Your name", "3", "field", "3"])
        #expect(try await page.survey().element(1).value == "Ana")
    }

    @Test("every type the fill script says it can write into is one it writes into", arguments: [
        "", "text", "email", "search", "tel", "url", "password",
        "number", "date", "time", "month", "week", "datetime-local",
    ])
    func everyTypableTypeIsWritable(kind: String) async throws {
        let attribute = kind.isEmpty ? "" : #" type="\#(kind)""#
        let page = try await BrowserPageFixture.body(
            #"<input\#(attribute) aria-label="Field">"#
        )
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "2026-10-10"))

        #expect(answer.first == "done")
    }

    @Test("a thing that is not a field is refused rather than filled", arguments: [
        #"<select aria-label="Choice"><option>One</option></select>"#,
        #"<input type="checkbox" aria-label="Box">"#,
        #"<input type="radio" aria-label="Ring">"#,
        #"<input type="file" aria-label="Upload">"#,
        #"<input type="range" aria-label="Slide">"#,
        #"<input type="color" aria-label="Ink">"#,
        #"<input type="submit" value="Send">"#,
        #"<input type="button" value="Press">"#,
        #"<button>Press</button>"#,
        #"<a href="/go">Link</a>"#,
    ])
    func somethingThatIsNotAFieldIsRefused(markup: String) async throws {
        let page = try await BrowserPageFixture.body(markup)
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "anything"))

        #expect(answer.first == "unwritable")
    }

    @Test("a refused fill says what browser_fill is for rather than claiming it wrote")
    func theRefusalSaysWhatFillIsFor() async throws {
        let page = try await BrowserPageFixture.body(
            #"<select aria-label="Choice"><option>One</option></select>"#
        )
        try await page.snapshot()

        guard case .failure(let refusal) = try await page.acted(.filling(1, with: "One")) else {
            Issue.record("a fill into a select was reported as done")
            return
        }

        #expect(refusal.sentence.contains("is not a field"))
        #expect(refusal.sentence.contains("browser_click"))
    }

    @Test("a field that keeps nothing of what was offered is reported as keeping nothing")
    func theReadBackIsNotTheOffer() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="number" aria-label="How many">"#
        )
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "a dozen"))
        #expect(answer == ["done", "How many", "0", "field", "7"])

        let sentence = try #require(try? (try await page.acted(.filling(1, with: "a dozen"))).get())
        #expect(sentence.contains("Typed 7 characters"))
        #expect(sentence.contains("now holds 0"))
        #expect(sentence.contains("did not keep what was offered"))
    }

    @Test("a field that keeps part of what was offered says so too")
    func aTruncatedFieldIsReportedWhole() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" maxlength="4" aria-label="Short">"#
        )
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "abcdefgh"))

        #expect(answer == ["done", "Short", "8", "field", "8"])
    }

    @Test("a field the page will not take is refused rather than written to", arguments: [
        #"<input type="text" readonly aria-label="Fixed">"#,
        #"<input type="text" disabled aria-label="Fixed">"#,
        #"<input type="text" aria-disabled="true" aria-label="Fixed">"#,
    ])
    func aBlockedFieldIsRefused(markup: String) async throws {
        let page = try await BrowserPageFixture.body(markup)
        try await page.snapshot()

        let answer = try await page.answer(.filling(1, with: "written"))

        #expect(answer == ["disabled", "Fixed"])
        #expect(try await page.survey().element(1).value == "")
    }

    @Test("a text area and a thing the page marks editable are both fields")
    func anEditableThingIsAField() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <textarea aria-label="Area"></textarea>
            <div contenteditable="true" aria-label="Editable"></div>
            """
        )
        try await page.snapshot()

        #expect(try await page.answer(.filling(1, with: "lines")) == ["done", "Area", "5", "field", "5"])
        #expect(
            try await page.answer(.filling(2, with: "words"))
                == ["done", "Editable", "5", "field", "5"]
        )
        #expect(try await page.visibleText().contains("words"))
    }

    @Test("a fill tells the page it happened, in a way a handler above the field hears")
    func theEventsBubble() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <form oninput="log.textContent += 'input '" onchange="log.textContent += 'change '">
              <input type="text" aria-label="Field">
            </form>
            """
        )
        try await page.snapshot()

        #expect(try await page.answer(.filling(1, with: "typed")).first == "done")

        let heard = try await page.visibleText()
        #expect(heard.contains("input"))
        #expect(heard.contains("change"))
    }

    @Test("a fill before any snapshot, or at a field that has gone, writes nothing")
    func aFillNeedsSomethingToPointAt() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <button onclick="target.remove()">Remove</button>
            <input id="target" type="text" aria-label="Field">
            """
        )
        #expect(try await page.answer(.filling(2, with: "early")) == ["gone"])

        try await page.snapshot()
        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.answer(.filling(2, with: "late")) == ["gone"])
    }
}
