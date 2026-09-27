import Foundation
import Testing
@testable import Core

@Suite("Document preview responses", .scratchDirectory)
struct DocumentPreviewResponseTests {
    @Test("only HTML has a preview")
    func onlyHTML() {
        #expect(DocumentPreview.hasPreview(path: "docs/report.html"))
        #expect(DocumentPreview.hasPreview(path: "INDEX.HTM"))
        #expect(!DocumentPreview.hasPreview(path: "README.md"))
        #expect(!DocumentPreview.hasPreview(path: "logo.svg"))
        #expect(!DocumentPreview.hasPreview(path: "page.xhtml"))
        #expect(!DocumentPreview.hasPreview(path: "html"))
    }

    @Test("text is declared UTF-8 and a document is served as HTML")
    func contentTypes() {
        #expect(DocumentPreview.contentType(forFile: "report.html") == "text/html; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "index.HTM") == "text/html; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "app.css") == "text/css; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "app.mjs") == "text/javascript; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "data.json") == "application/json; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "chart.svg") == "image/svg+xml; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "flow.png") == "image/png")
        #expect(DocumentPreview.contentType(forFile: "notes.txt") == "text/plain; charset=utf-8")
        #expect(DocumentPreview.contentType(forFile: "blob.unknownextension") == "application/octet-stream")
    }

    @Test("the policy names no network origin at all")
    func policyHasNoNetwork() throws {
        let policy = DocumentPreview.contentSecurityPolicy
        #expect(!policy.contains("http"))
        #expect(!policy.contains("ws:"))
        #expect(!policy.contains("*"))
        #expect(!policy.contains("unsafe-eval"))

        let directives = Dictionary(uniqueKeysWithValues: policy.components(separatedBy: "; ").map { directive in
            let parts = directive.split(separator: " ", maxSplits: 1).map(String.init)
            return (parts[0], parts.count > 1 ? parts[1] : "")
        })
        #expect(directives["default-src"] == "'self' unified-dev-preview:")
        #expect(directives["script-src"] == "'self' unified-dev-preview: 'unsafe-inline'")
        #expect(directives["connect-src"] == "'self' unified-dev-preview:")
        #expect(directives["frame-src"] == "'self' unified-dev-preview:")
        #expect(directives["object-src"] == "'none'")
        #expect(directives["form-action"] == "'none'")
    }

    @Test("every response carries the policy and is never cached")
    func headers() {
        let headers = DocumentPreview.responseHeaders(contentType: "text/html; charset=utf-8", length: 42)
        #expect(headers["Content-Type"] == "text/html; charset=utf-8")
        #expect(headers["Content-Length"] == "42")
        #expect(headers["Cache-Control"] == "no-store")
        #expect(headers["Content-Security-Policy"] == DocumentPreview.contentSecurityPolicy)
        #expect(headers["X-Content-Type-Options"] == "nosniff")
    }

    @Test("the fingerprint moves when the file or its unsaved text does")
    func fingerprint() throws {
        let path = TestScratch.unique("report") + ".html"
        try "x".write(toFile: path, atomically: true, encoding: .utf8)
        let before = DocumentPreview.fingerprint(forFile: path, draft: nil)
        try "longer contents".write(toFile: path, atomically: true, encoding: .utf8)
        #expect(DocumentPreview.fingerprint(forFile: path, draft: nil) != before)
        #expect(DocumentPreview.fingerprint(forFile: path, draft: "a") != DocumentPreview.fingerprint(forFile: path, draft: "b"))
        #expect(DocumentPreview.fingerprint(forFile: path + ".missing", draft: nil) == "missing")
    }

    @Test("a file on disk is answered with its bytes and its type")
    func readsTheDisk() throws {
        let path = TestScratch.unique("report") + ".html"
        try "<h1>caf\u{e9}</h1>".write(toFile: path, atomically: true, encoding: .utf8)
        let answer = DocumentPreviewAnswer.read(URL(filePath: path), draft: nil)
        #expect(answer.status == 200)
        #expect(answer.type == "text/html; charset=utf-8")
        #expect(answer.body == Data("<h1>caf\u{e9}</h1>".utf8))
    }

    @Test("unsaved text is answered in place of the disk")
    func draftWins() throws {
        let path = TestScratch.unique("report") + ".html"
        try "old".write(toFile: path, atomically: true, encoding: .utf8)
        let answer = DocumentPreviewAnswer.read(URL(filePath: path), draft: "new")
        #expect(answer.status == 200)
        #expect(answer.body == Data("new".utf8))
    }

    @Test("a missing file or a folder is a 404, and a refusal is a 403")
    func failures() throws {
        let folder = TestScratch.unique("folder")
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        #expect(DocumentPreviewAnswer.read(URL(filePath: folder + "/missing.html"), draft: nil).status == 404)
        #expect(DocumentPreviewAnswer.read(URL(filePath: folder), draft: nil).status == 404)
        #expect(DocumentPreviewAnswer.refused.status == 403)
        #expect(DocumentPreviewAnswer.refused.type == "text/plain; charset=utf-8")
    }
}
