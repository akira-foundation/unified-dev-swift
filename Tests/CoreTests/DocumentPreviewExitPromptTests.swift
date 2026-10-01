import Foundation
import Testing
@testable import Core

@Suite("Leaving an HTML preview", .tags(.security))
struct DocumentPreviewExitPromptTests {
    @Test("the question names the host, not the whole address")
    func namesTheHost() throws {
        let url = try #require(URL(string: "https://example.com/very/long/path?d=stolen"))
        let prompt = DocumentPreviewExitPrompt.asking(about: url)
        #expect(prompt.title == "Open example.com in your browser?")
        #expect(prompt.confirm == "Open in Browser")
        #expect(prompt.message.contains("example.com/very/long/path"))
        #expect(prompt.message.contains("a page can put anything it has read into a link"))
    }

    @Test("mail is asked about as mail")
    func mail() throws {
        let url = try #require(URL(string: "mailto:someone@example.com"))
        let prompt = DocumentPreviewExitPrompt.asking(about: url)
        #expect(prompt.title == "Write to someone@example.com?")
        #expect(prompt.confirm == "Open Mail")
    }

    @Test("an address with no host still asks before it opens")
    func hostless() throws {
        let url = try #require(URL(string: "https:///page"))
        let prompt = DocumentPreviewExitPrompt.asking(about: url)
        #expect(prompt.title == "Open another site in your browser?")
        #expect(!prompt.message.isEmpty)
    }
}
