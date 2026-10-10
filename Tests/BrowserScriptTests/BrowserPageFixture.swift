@testable import Core
import Foundation
import Testing
import WebKit

@MainActor
final class BrowserPageFixture {
    static let firstAddress = "https://fixture.invalid/one"

    private static let world = WKContentWorld.world(name: BrowserAgentScript.world)

    private static let offscreen = CGRect(x: 0, y: 0, width: 1_280, height: 800)

    private let webView: WKWebView

    private init(_ webView: WKWebView) {
        self.webView = webView
    }

    static func body(_ markup: String, head: String = "") async throws -> BrowserPageFixture {
        let fixture = BrowserPageFixture(WKWebView(frame: offscreen))
        try await fixture.reload(document(markup, head: head), at: firstAddress)
        return fixture
    }

    static func document(_ markup: String, head: String = "") -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8">\(head)</head><body>
        \(markup)
        </body></html>
        """
    }

    func reload(_ document: String, at address: String) async throws {
        webView.loadHTMLString(document, baseURL: URL(string: address))
        try await settle()
    }

    func settle(within milliseconds: Int = 10_000) async throws {
        let deadline = ContinuousClock.now + .milliseconds(milliseconds)
        while webView.isLoading, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(!webView.isLoading, "the fixture page never finished loading")
    }

    func run(_ script: BrowserAgentScript) async throws -> Any? {
        try await webView.callAsyncJavaScript(
            script.body,
            arguments: script.arguments.mapped(),
            contentWorld: Self.world
        )
    }

    func snapshot() async throws {
        _ = try await survey()
    }

    func survey() async throws -> BrowserPageSurvey {
        try BrowserPageOutline.survey(try await run(.outline)).get()
    }

    func listing() async throws -> String {
        BrowserPageOutline.render(try await survey(), from: Self.firstAddress)
    }

    func answer(_ script: BrowserAgentScript) async throws -> [String] {
        try await run(script) as? [String] ?? []
    }

    func acted(_ script: BrowserAgentScript) async throws -> Result<String, PaneRefusal> {
        BrowserAgentOutcome.acted(try await answer(script), for: script)
    }

    func reading(_ condition: BrowserWaitCondition) async throws -> BrowserWaitReading {
        BrowserAgentOutcome.read(try await answer(.settled(condition)))
    }

    func visibleText() async throws -> String {
        try await read(.visibleText) { $0 as? String }
    }

    func scrolled(_ scroll: BrowserScroll) async throws -> BrowserViewport {
        try await read(.scroll(scroll)) { value -> BrowserViewport? in
            guard let list = value as? [Any] else { return nil }
            let numbers = list.compactMap { ($0 as? NSNumber)?.intValue }
            guard numbers.count == 3 else { return nil }
            return BrowserViewport(offset: numbers[0], height: numbers[1], viewport: numbers[2])
        }
    }

    func read<Value: Sendable>(
        _ script: BrowserPageScript, as reader: @escaping @Sendable (Any?) -> Value?
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script.source) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let read = reader(value) else {
                    continuation.resume(throwing: PaneRefusal("the page answered \(String(describing: value))"))
                    return
                }
                continuation.resume(returning: read)
            }
        }
    }
}

struct BrowserViewport: Sendable, Equatable {
    let offset: Int
    let height: Int
    let viewport: Int
}

extension BrowserPageSurvey {
    func element(_ index: Int) throws -> BrowserPageElement {
        try #require(elements.indices.contains(index - 1), "there is no e\(index) in \(elements.count)")
        return elements[index - 1]
    }

    var names: [String] { elements.map(\.name) }

    var roles: [String] { elements.map(\.role) }
}

extension BrowserAgentScript {
    static func clicking(_ index: Int) -> BrowserAgentScript {
        .click(BrowserAgentReference(index: index))
    }

    static func filling(_ index: Int, with text: String) -> BrowserAgentScript {
        .fill(BrowserAgentReference(index: index), text)
    }

    static func pressing(_ key: BrowserKeyPress, at index: Int?) -> BrowserAgentScript {
        .press(key, index.map { BrowserAgentReference(index: $0) })
    }
}
