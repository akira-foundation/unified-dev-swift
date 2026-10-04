import AppKit
import Core
import WebKit

extension BrowserSession {
    private static let offscreenSize = CGSize(width: 1_280, height: 800)

    func prepareForAgent() {
        guard webView.window == nil, webView.bounds.isEmpty else { return }
        pageView.frame = CGRect(origin: .zero, size: Self.offscreenSize)
        webView.frame = pageView.bounds
    }

    func settle(within milliseconds: Int = 10_000) async {
        let deadline = ContinuousClock.now + .milliseconds(milliseconds)
        while webView.isLoading, !Task.isCancelled, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}

extension BrowserSession {
    static let agentWorld = WKContentWorld.world(name: BrowserAgentScript.world)

    func callAgentScript(_ script: BrowserAgentScript) async throws -> Any? {
        try await webView.callAsyncJavaScript(
            script.body,
            arguments: script.arguments.mapped(),
            contentWorld: Self.agentWorld
        )
    }
}

extension [String: BrowserScriptValue] {
    func mapped() -> [String: Any] {
        mapValues { value -> Any in
            switch value {
            case .text(let text): text
            case .number(let number): number
            case .flag(let flag): flag
            }
        }
    }
}
