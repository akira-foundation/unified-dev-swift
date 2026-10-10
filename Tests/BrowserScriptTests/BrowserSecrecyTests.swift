import Core
import Testing

@MainActor
@Suite("What the scripts treat as a password", .serialized, .tags(.security))
struct BrowserSecrecyTests {
    private static let secret = "correct-horse-battery"

    @Test("a field is a password when its type says so, when it says so, or when the page masks it", arguments: [
        #"<input type="password" aria-label="Field">"#,
        #"<input type="text" autocomplete="current-password" aria-label="Field">"#,
        #"<input type="text" autocomplete="new-password" aria-label="Field">"#,
        #"<input type="text" autocomplete="SECTION-one current-PASSWORD" aria-label="Field">"#,
        #"<input type="text" style="-webkit-text-security: disc" aria-label="Field">"#,
        #"<input type="text" style="-webkit-text-security: square" aria-label="Field">"#,
    ])
    func maskedFieldsAreSecret(markup: String) async throws {
        let page = try await BrowserPageFixture.body(markup)
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: Self.secret))
        #expect(filled.first == "done")

        let element = try await page.survey().element(1)
        #expect(element.isPassword)
        #expect(element.value == nil)
        #expect(element.valueLength == Self.secret.count)
    }

    @Test("a plain field is not a password, and its value is read back")
    func aPlainFieldIsNotSecret() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" aria-label="Field" autocomplete="username">"#
        )
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: "someone"))
        #expect(filled.first == "done")

        let element = try await page.survey().element(1)
        #expect(!element.isPassword)
        #expect(element.value == "someone")
    }

    @Test("a page that masks a field from a stylesheet masks it as far as the script is concerned")
    func maskingFromAStylesheetCounts() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" class="masked" aria-label="Field">"#,
            head: "<style>.masked { -webkit-text-security: disc }</style>"
        )
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: Self.secret))

        #expect(filled.count > 3)
        #expect(filled[3] == "password")
        #expect(try await page.survey().element(1).isPassword)
    }

    @Test("a page that says it masks nothing is not masking anything")
    func sayingNoneIsNotMasking() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="text" style="-webkit-text-security: none" aria-label="Field">"#
        )
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: "plain"))

        #expect(filled.count > 3)
        #expect(filled[3] == "field")
        #expect(!(try await page.survey().element(1).isPassword))
    }

    @Test("a button a page offers for showing a password does not stop it being one")
    func aShownPasswordIsStillAPassword() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <input id="secret" type="password" autocomplete="current-password" aria-label="Field">
            <button onclick="secret.type = 'text'">Show</button>
            """
        )
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: Self.secret))
        #expect(filled.first == "done")
        let shown = try await page.answer(.clicking(2))
        #expect(shown.first == "done")

        let element = try await page.survey().element(1)
        #expect(element.role == "textbox")
        #expect(element.isPassword)
        #expect(element.value == nil)
    }

    @Test("what the owner is shown about a password is a length, and never the password")
    func theListingCarriesNoPassword() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="password" aria-label="Your password">"#
        )
        try await page.snapshot()
        let filled = try await page.answer(.filling(1, with: Self.secret))
        #expect(filled.first == "done")

        let listing = try await page.listing()
        #expect(!listing.contains(Self.secret))
        #expect(listing.contains("holds \(Self.secret.count) characters"))
    }

    @Test("the sentence about a filled password says the length is the whole of the answer")
    func theSentenceSaysWhatItDidNotRead() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="password" aria-label="Your password">"#
        )
        try await page.snapshot()
        let acted = try await page.acted(.filling(1, with: Self.secret))

        let sentence = try #require(try? acted.get())
        #expect(!sentence.contains(Self.secret))
        #expect(sentence.contains("does not read a password field back"))
        #expect(sentence.contains("\(Self.secret.count) characters"))
    }

    @Test("only an input is judged this way, which is what the bridge document calls a gap")
    func onlyAnInputIsJudged() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <textarea aria-label="Area" autocomplete="current-password"
                      style="-webkit-text-security: disc"></textarea>
            <div contenteditable="true" aria-label="Editable"
                 style="-webkit-text-security: disc"></div>
            """
        )
        let survey = try await page.survey()

        #expect(survey.elements.map(\.isPassword) == [false, false])
    }
}
