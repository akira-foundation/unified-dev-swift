import AppKit

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
