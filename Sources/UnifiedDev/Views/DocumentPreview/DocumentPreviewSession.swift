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
        schemes.draft = draft
        let next = DocumentPreview.fingerprint(forFile: document, draft: draft)
        guard next != fingerprint else { return }
        fingerprint = next
        if webView.url == nil {
            guard let address = DocumentPreview.address(forFile: document, root: root) else { return }
            webView.load(URLRequest(url: address))
        } else {
            webView.reload()
        }
    }

    func close() {
        webView.stopLoading()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.navigationDelegate = nil
    }

    func decide(_ action: WKNavigationAction) -> WKNavigationActionPolicy {
        guard let target = action.request.url else { return .cancel }
        let decision = DocumentPreviewNavigation.decide(
            target: target, document: document, root: root,
            isMainFrame: action.targetFrame?.isMainFrame ?? true,
            isLinkActivated: action.navigationType == .linkActivated
        )
        switch decision {
        case .allow:
            return .allow
        case let .openFile(path):
            openFile?(path)
            return .cancel
        case let .openExternally(url):
            NSWorkspace.shared.open(url)
            return .cancel
        case .refuse:
            return .cancel
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
