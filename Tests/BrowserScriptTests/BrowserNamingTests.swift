@testable import Core
import Testing

@MainActor
@Suite("The words and the role the outline script gives an element", .serialized)
struct BrowserNamingTests {
    @Test("aria-label comes before the label the page draws beside the field")
    func ariaLabelWins() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <label for="one">Drawn beside it</label>
            <input id="one" aria-label="Spoken" placeholder="Typed into it" title="Hovered">
            """
        )

        #expect(try await page.survey().names == ["Spoken"])
    }

    @Test("the label beside the field comes before its placeholder")
    func theLabelBeatsThePlaceholder() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <label for="two">Drawn beside it</label>
            <input id="two" placeholder="Typed into it" title="Hovered">
            """
        )

        #expect(try await page.survey().names == ["Drawn beside it"])
    }

    @Test("the placeholder comes before the title")
    func thePlaceholderBeatsTheTitle() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input placeholder="Typed into it" title="Hovered" alt="Pictured">"#
        )

        #expect(try await page.survey().names == ["Typed into it"])
    }

    @Test("the title comes before the alternative text")
    func theTitleBeatsTheAlternative() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input type="image" title="Hovered" alt="Pictured">"#
        )

        #expect(try await page.survey().names == ["Hovered"])
    }

    @Test("the alternative text comes before the words inside the element")
    func theAlternativeBeatsTheWordsInside() async throws {
        let page = try await BrowserPageFixture.body(
            #"<div role="button" alt="Pictured">Written inside</div>"#
        )

        #expect(try await page.survey().names == ["Pictured"])
    }

    @Test("the words inside come before the name the field would submit")
    func theWordsInsideBeatTheSubmittedName() async throws {
        let page = try await BrowserPageFixture.body(
            #"<button name="submitted">Written inside</button>"#
        )

        #expect(try await page.survey().names == ["Written inside"])
    }

    @Test("the name the field would submit is the last thing tried")
    func theSubmittedNameIsTheLastResort() async throws {
        let page = try await BrowserPageFixture.body(#"<input name="submitted">"#)

        #expect(try await page.survey().names == ["submitted"])
    }

    @Test("an element with nothing to call it is listed with no words rather than left out")
    func anUnnamedElementIsStillListed() async throws {
        let page = try await BrowserPageFixture.body("<input>")
        let survey = try await page.survey()

        #expect(survey.names == [""])
        #expect(try await page.listing().contains("textbox \"\" [e1]"))
    }

    @Test("the first label the page gives a field is the one the field is called by")
    func theFirstLabelWins() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <label for="three">Called this</label>
            <input id="three">
            <label for="three">Also called this</label>
            """
        )

        #expect(try await page.survey().names == ["Called this"])
    }

    @Test("a label the page left empty is no label at all")
    func anEmptyLabelFallsThrough() async throws {
        let page = try await BrowserPageFixture.body(
            #"<input aria-label="" placeholder="Typed into it">"#
        )

        #expect(try await page.survey().names == ["Typed into it"])
    }

    @Test("the words are put on one line and the runs of space are closed up", arguments: [
        "<button style=\"white-space: pre\">  Send\nthe\nform  </button>",
        "<input aria-label=\"  Send&#10;the&#10;form  \">",
        "<input title=\"Send&#9;&#9;the   form\">",
    ])
    func theWordsAreFlattened(markup: String) async throws {
        let page = try await BrowserPageFixture.body(markup)

        #expect(try await page.survey().names == ["Send the form"])
    }

    @Test("the outline cuts a label at its own limit, and an action at the shorter one")
    func theTwoLimitsAreTheTwoNumbers() async throws {
        let long = String(repeating: "w", count: BrowserPageOutline.nameLimit + 40)
        let page = try await BrowserPageFixture.body("<button>\(long)</button>")

        let survey = try await page.survey()
        #expect(try survey.element(1).name.count == BrowserPageOutline.nameLimit)

        let answer = try await page.answer(.clicking(1))
        #expect(answer.count == 2)
        #expect(answer[1].count == BrowserAgentScript.labelLimit)
    }

    @Test("the role an element is given is the role it is listed with")
    func anExplicitRoleWins() async throws {
        let page = try await BrowserPageFixture.body(
            #"<button role="link" aria-label="Pretending">Pretending</button>"#
        )

        #expect(try await page.survey().roles == ["link"])
    }

    @Test("a tag with no role of its own is named by what it is", arguments: [
        ("<a href=\"/go\" aria-label=\"x\">x</a>", "link"),
        ("<select aria-label=\"x\"><option>o</option></select>", "combobox"),
        ("<textarea aria-label=\"x\"></textarea>", "textbox"),
        ("<details><summary>x</summary>y</details>", "disclosure"),
        ("<input aria-label=\"x\">", "textbox"),
        ("<input type=\"text\" aria-label=\"x\">", "textbox"),
        ("<input type=\"password\" aria-label=\"x\">", "textbox"),
        ("<input type=\"checkbox\" aria-label=\"x\">", "checkbox"),
        ("<input type=\"radio\" aria-label=\"x\">", "radio"),
        ("<input type=\"submit\" value=\"x\">", "button"),
        ("<input type=\"button\" value=\"x\">", "button"),
        ("<input type=\"reset\" value=\"x\">", "button"),
        ("<input type=\"email\" aria-label=\"x\">", "email"),
        ("<input type=\"number\" aria-label=\"x\">", "number"),
        ("<button>x</button>", "button"),
    ])
    func rolesComeFromTheTag(markup: String, role: String) async throws {
        let page = try await BrowserPageFixture.body(markup)

        #expect(try await page.survey().roles == [role])
    }

    @Test("the depth is how many groups the element sits inside, and a plain wrapper is none")
    func theDepthCountsGroups() async throws {
        let page = try await BrowserPageFixture.body(
            """
            <button>Loose</button>
            <div><button>Wrapped</button></div>
            <form><button>Formed</button></form>
            <form><fieldset><ul><li><button>Buried</button></li></ul></fieldset></form>
            """
        )
        let survey = try await page.survey()

        #expect(survey.elements.map(\.depth) == [0, 0, 1, 3])
    }

    @Test("every tag the script counts as a group counts as one", arguments: [
        "<form><button>In</button></form>",
        "<fieldset><button>In</button></fieldset>",
        "<nav><button>In</button></nav>",
        "<section><button>In</button></section>",
        "<aside><button>In</button></aside>",
        "<table><tr><td><button>In</button></td></tr></table>",
        "<ul><li><button>In</button></li></ul>",
        "<ol><li><button>In</button></li></ol>",
        "<dialog open><button>In</button></dialog>",
    ])
    func eachGroupIsAGroup(markup: String) async throws {
        let page = try await BrowserPageFixture.body(markup)
        let survey = try await page.survey()

        #expect(try survey.element(1).depth == 1)
    }

    @Test("a depth past the indentation ceiling is reported whole and indented no further")
    func theCeilingIsInTheRenderingAndNotInThePage() async throws {
        let groups = ["form", "fieldset", "nav", "section", "aside", "ul"]
        let opened = groups.map { "<\($0)>" }.joined()
        let closed = groups.reversed().map { "</\($0)>" }.joined()
        let page = try await BrowserPageFixture.body(opened + "<button>Deep</button>" + closed)

        let survey = try await page.survey()
        #expect(try survey.element(1).depth == groups.count)
        #expect(groups.count > BrowserPageOutline.depthLimit)

        let indented = String(repeating: "  ", count: BrowserPageOutline.depthLimit)
        let listing = try await page.listing()
        #expect(listing.contains("\n\(indented)- button \"Deep\" [e1]"))
        #expect(!listing.contains("\n\(indented)  - button"))
    }
}
