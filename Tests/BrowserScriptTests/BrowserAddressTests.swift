import Core
import Testing

@MainActor
@Suite("What happens to a reference when a page changes its address", .serialized)
struct BrowserAddressTests {
    private static func moving(_ javaScript: String) -> String {
        """
        <button onclick="\(javaScript)">Go</button>
        <button>Target</button>
        """
    }

    @Test("a page that changes its address without navigating loses every reference", arguments: [
        "history.pushState({}, '', '/two')",
        "history.replaceState({}, '', '/two')",
        "location.hash = 'two'",
    ])
    func movingTheAddressClearsTheRegister(javaScript: String) async throws {
        let page = try await BrowserPageFixture.body(Self.moving(javaScript))
        let survey = try await page.survey()
        #expect(survey.names == ["Go", "Target"])

        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.answer(.clicking(2)) == ["gone"])
    }

    @Test("a document that replaces another starts with a register of its own")
    func anotherDocumentStartsEmpty() async throws {
        let page = try await BrowserPageFixture.body("<button>Target</button>")
        #expect(try await page.survey().names == ["Target"])
        #expect(try await page.answer(.clicking(1)) == ["done", "Target"])

        try await page.reload(
            BrowserPageFixture.document("<button>Later</button>"),
            at: "https://fixture.invalid/two"
        )

        #expect(try await page.answer(.clicking(1)) == ["gone"])
        #expect(try await page.survey().names == ["Later"])
    }

    @Test("a reference survives a page that stays where it is")
    func stayingPutKeepsTheRegister() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <p id="log"></p>
            <button onclick="log.textContent += 'pressed '">Press</button>
            <button>Target</button>
            """
        )
        try await page.snapshot()

        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.answer(.clicking(2)) == ["done", "Target"])
    }

    @Test("a fresh snapshot after the address moved hands out references that work again")
    func aFreshSnapshotStartsOver() async throws {
        let page = try await BrowserPageFixture.body(
            Self.moving("history.pushState({}, '', '/two')")
        )
        try await page.snapshot()
        #expect(try await page.answer(.clicking(1)).first == "done")
        #expect(try await page.answer(.clicking(2)) == ["gone"])

        let second = try await page.survey()
        #expect(second.names == ["Go", "Target"])
        #expect(try await page.answer(.clicking(2)) == ["done", "Target"])
    }

    @Test("a wait does not resurrect a reference the moved address killed")
    func aWaitKeepsTheAddressUpToDate() async throws {
        let page = try await BrowserPageFixture.body(
            Self.moving("history.pushState({}, '', '/two')")
        )
        try await page.snapshot()
        #expect(try await page.answer(.clicking(1)).first == "done")

        #expect(try await page.reading(.load) == .met)
        #expect(try await page.answer(.clicking(2)) == ["gone"])
    }

    @Test("a fill at an element whose page has moved on writes nothing")
    func aFillIsStoppedTheSameWay() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <button onclick="history.pushState({}, '', '/two')">Go</button>
            <input type="text" aria-label="Field">
            """
        )
        try await page.snapshot()
        #expect(try await page.answer(.clicking(1)).first == "done")

        #expect(try await page.answer(.filling(2, with: "written")) == ["gone"])
        #expect(try await page.survey().element(2).value == "")
    }
}
