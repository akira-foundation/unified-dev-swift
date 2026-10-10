import Core
import Testing

@MainActor
@Suite("What a key press delivers to a page", .serialized)
struct BrowserPressingTests {
    private static let recorder = """
        <p id="log"></p>
        <script>
        function record(event) {
          log.textContent = [
            event.type, event.key, event.code, event.keyCode, event.which, event.isTrusted
          ].join(" ");
        }
        </script>
        """

    @Test("each key the agent may name arrives as that key, with the number pages read", arguments: [
        (BrowserKeyPress.enter, "Enter", 13),
        (.tab, "Tab", 9),
        (.escape, "Escape", 27),
        (.backspace, "Backspace", 8),
        (.up, "ArrowUp", 38),
        (.down, "ArrowDown", 40),
        (.left, "ArrowLeft", 37),
        (.right, "ArrowRight", 39),
    ])
    func everyKeyArrivesAsItself(key: BrowserKeyPress, named: String, number: Int) async throws {
        let page = try await BrowserPageFixture.body(
            Self.recorder + #"<input type="text" aria-label="Field" onkeydown="record(event)">"#
        )
        try await page.snapshot()

        let answer = try await page.answer(.pressing(key, at: 1))
        #expect(answer == ["done", "Field"])

        let heard = try await page.visibleText().trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(heard == "keydown \(named) \(named) \(number) \(number) false")
    }

    @Test("both halves of a press reach the page")
    func bothHalvesArrive() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <input type="text" aria-label="Field"
                   onkeydown="log.textContent += 'down '" onkeyup="log.textContent += 'up '">
            """
        )
        try await page.snapshot()

        #expect(try await page.answer(.pressing(.enter, at: 1)).first == "done")
        #expect(try await page.visibleText().contains("down up"))
    }

    @Test("a press that names no element goes to whatever the page has focused")
    func aPageWidePressFollowsTheFocus() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <input type="text" aria-label="First" onkeydown="log.textContent = 'first'">
            <input type="text" aria-label="Second" onkeydown="log.textContent = 'second'">
            """
        )
        try await page.snapshot()
        #expect(try await page.answer(.clicking(2)).first == "done")

        let answer = try await page.answer(.pressing(.enter, at: nil))

        #expect(answer == ["done", ""])
        #expect(try await page.visibleText().contains("second"))
    }

    @Test("a press at an element that has gone sends nothing")
    func aPressNeedsItsElement() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <button onclick="target.remove()">Remove</button>
            <input id="target" type="text" aria-label="Field"
                   onkeydown="log.textContent = 'heard'">
            """
        )
        try await page.snapshot()
        #expect(try await page.answer(.clicking(1)).first == "done")

        #expect(try await page.answer(.pressing(.enter, at: 2)) == ["gone"])
        #expect(!(try await page.visibleText().contains("heard")))
    }

    @Test("a press focuses the element it names, so the page reads the right one as active")
    func aPressFocusesWhatItNames() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <input type="text" aria-label="First">
            <input type="text" aria-label="Second">
            <script>
            document.addEventListener("keydown", function (event) {
              log.textContent = document.activeElement.getAttribute("aria-label") || "none";
            });
            </script>
            """
        )
        try await page.snapshot()
        #expect(try await page.answer(.pressing(.enter, at: 1)).first == "done")
        #expect(try await page.visibleText().contains("First"))

        #expect(try await page.answer(.pressing(.enter, at: 2)).first == "done")
        #expect(try await page.visibleText().contains("Second"))
    }

    @Test("the sentence says the press was synthetic, because a page can tell")
    func theSentenceSaysItIsSynthetic() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" aria-label="Field">"#
        )
        try await page.snapshot()

        let sentence = try #require(try? (try await page.acted(.pressing(.enter, at: 1))).get())

        #expect(sentence.contains("Sent enter to e1"))
        #expect(sentence.contains("isTrusted is false"))
    }
}
