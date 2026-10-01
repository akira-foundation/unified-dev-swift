import AppKit
import WebKit
import Core

@MainActor
final class DocumentPreviewSession {
    let webView: WKWebView
    let host = BrowserHostView()
    private let schemes: DocumentPreviewSchemeHandler
    private let navigation = DocumentPreviewNavigator()
    private let scroll = DocumentPreviewScrollListener()
    private let document: String
    private let root: String
    private var fingerprint: String?
    private var hasLoaded = false
    private var isAsking = false
    private var draft: String?
    private var watch: Task<Void, Never>?

    private static var positions: [String: CGPoint] = [:]

    var openFile: ((String) -> Void)?

    init(document: String, root: String) {
        self.document = document
        self.root = root
        schemes = DocumentPreviewSchemeHandler(root: root, document: document)

        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemes, forURLScheme: DocumentPreview.scheme)
        configuration.websiteDataStore = .nonPersistent()
        let controller = configuration.userContentController
        controller.add(scroll, contentWorld: .defaultClient, name: DocumentPreviewScrollListener.name)
        controller.addUserScript(WKUserScript(
            source: DocumentPreviewScrollListener.source, injectionTime: .atDocumentEnd,
            forMainFrameOnly: true, in: .defaultClient
        ))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = NSColor(Palette.surface)
        host.attach(webView)

        scroll.onScroll = { [document] point in Self.positions[document] = point }
        navigation.owner = self
        webView.navigationDelegate = navigation
    }

    func update(draft: String?) {
        self.draft = draft
        schemes.draft = draft
        watchForChanges()
        let next = DocumentPreview.fingerprint(
            forFiles: [document] + schemes.served.filter { $0 != document }, draft: draft
        )
        guard next != fingerprint else { return }
        fingerprint = next
        guard let address = DocumentPreview.address(forFile: document, root: root) else { return }
        schemes.forget()
        hasLoaded = true
        webView.load(URLRequest(url: address))
    }

    private func watchForChanges() {
        guard watch == nil else { return }
        watch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                self.update(draft: self.draft)
            }
        }
    }

    func close() {
        watch?.cancel()
        watch = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.navigationDelegate = nil
        webView.removeFromSuperview()
        hasLoaded = false
    }

    func decide(_ action: WKNavigationAction) -> WKNavigationActionPolicy {
        guard let target = action.request.url else { return .cancel }
        let decision = DocumentPreviewNavigation.decide(
            target: target, document: document, root: root,
            isMainFrame: action.targetFrame?.isMainFrame ?? false,
            isFromMainFrame: action.sourceFrame.isMainFrame,
            isLinkActivated: action.navigationType == .linkActivated
        )
        switch decision {
        case .allow:
            return .allow
        case let .openFile(path):
            openFile?(path)
            return .cancel
        case let .openExternally(url):
            ask(about: url)
            return .cancel
        case .refuse:
            return .cancel
        }
    }

    private func ask(about url: URL) {
        guard !isAsking else { return }
        isAsking = true
        Task { @MainActor in
            defer { isAsking = false }
            if DocumentPreviewExit.confirm(url) { NSWorkspace.shared.open(url) }
        }
    }

    func restoreScroll() {
        guard let point = Self.positions[document], point != .zero else { return }
        webView.callAsyncJavaScript(
            DocumentPreviewScrollListener.restore, arguments: ["x": point.x, "y": point.y],
            in: nil, in: .defaultClient, completionHandler: nil
        )
    }
}

@MainActor
private final class DocumentPreviewNavigator: NSObject, WKNavigationDelegate {
    weak var owner: DocumentPreviewSession?

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        owner?.decide(navigationAction) ?? .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        owner?.restoreScroll()
    }
}
