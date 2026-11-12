@testable import Core
import Foundation
import Network
import Testing
import WebKit

@MainActor
@Suite("What a previewed document reaches over the network", .serialized, .tags(.security))
struct DocumentPreviewNetworkTests {
    @Test("a preconnect link, written or added by a script, opens no connection under the preview's rules")
    func preconnectIsBlocked() async throws {
        let listener = try await LoopbackListener.start()
        defer { listener.stop() }

        let page = try await PreviewPage.open(preconnectingTo: listener.port, blocked: true)
        try await Task.sleep(for: .seconds(3))

        #expect(try await page.bodyText() == "loaded")
        #expect(listener.connections == 0)
    }

    @Test("without the rules the same page does connect, so the test above can see one")
    func preconnectIsSeenWithoutTheRules() async throws {
        let listener = try await LoopbackListener.start()
        defer { listener.stop() }

        let page = try await PreviewPage.open(preconnectingTo: listener.port, blocked: false)
        let deadline = ContinuousClock.now + .seconds(10)
        while listener.connections == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(try await page.bodyText() == "loaded")
        #expect(listener.connections > 0)
    }
}

@MainActor
private final class PreviewPage {
    private let webView: WKWebView
    private let handler: PreviewDocumentHandler

    private init(webView: WKWebView, handler: PreviewDocumentHandler) {
        self.webView = webView
        self.handler = handler
    }

    static func open(preconnectingTo port: UInt16, blocked: Bool) async throws -> PreviewPage {
        let address = "http://127.0.0.1:\(port)/"
        let document = """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <link rel="preconnect" href="\(address)">
        <script>
        const link = document.createElement("link");
        link.rel = "preconnect";
        link.href = "\(address)";
        document.head.append(link);
        </script>
        </head><body>loaded</body></html>
        """
        let handler = PreviewDocumentHandler(document: document)
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(handler, forURLScheme: DocumentPreview.scheme)
        configuration.websiteDataStore = .nonPersistent()
        if blocked {
            let rules = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: DocumentPreview.networkRuleListIdentifier,
                encodedContentRuleList: DocumentPreview.networkRules
            )
            configuration.userContentController.add(try #require(rules))
        }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        let page = PreviewPage(webView: webView, handler: handler)
        webView.load(URLRequest(url: try #require(URL(string: "\(DocumentPreview.scheme)://worktree/index.html"))))
        let deadline = ContinuousClock.now + .seconds(10)
        while webView.isLoading || webView.url == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        return page
    }

    func bodyText() async throws -> String? {
        try await webView.evaluateJavaScript("document.body.textContent") as? String
    }
}

@MainActor
private final class PreviewDocumentHandler: NSObject, WKURLSchemeHandler {
    private let document: String

    init(document: String) {
        self.document = document
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let body = Data(document.utf8)
        let headers = DocumentPreview.responseHeaders(contentType: "text/html; charset=utf-8", length: body.count)
        guard let url = urlSchemeTask.request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
        else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(body)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

private final class LoopbackListener: @unchecked Sendable {
    private let listener: NWListener
    private let lock = NSLock()
    private var accepted = 0

    private init(_ listener: NWListener) {
        self.listener = listener
    }

    static func start() async throws -> LoopbackListener {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let wrapper = LoopbackListener(try NWListener(using: parameters))
        wrapper.listener.newConnectionHandler = { [wrapper] connection in
            wrapper.lock.withLock { wrapper.accepted += 1 }
            connection.cancel()
        }
        wrapper.listener.start(queue: .global())
        let deadline = ContinuousClock.now + .seconds(5)
        while wrapper.port == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(wrapper.port != 0, "the loopback listener never got a port")
        return wrapper
    }

    var port: UInt16 {
        listener.port?.rawValue ?? 0
    }

    var connections: Int {
        lock.withLock { accepted }
    }

    func stop() {
        listener.cancel()
    }
}
