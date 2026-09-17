import AppKit
import WebKit
import Core

@MainActor
final class BrowserUIObserver: NSObject, WKUIDelegate {
    weak var owner: BrowserSession?

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        owner?.openWindow(navigationAction.request.url)
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async {
        _ = await owner?.ask(.alert, message: message, from: Self.name(of: frame.securityOrigin))
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo
    ) async -> Bool {
        let answer = await owner?.ask(
            .confirm, message: message, from: Self.name(of: frame.securityOrigin)
        )
        return answer?.isConfirmed ?? false
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        let answer = await owner?.ask(
            .prompt,
            message: prompt,
            defaultText: defaultText ?? "",
            from: Self.name(of: frame.securityOrigin)
        )
        return answer?.text
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo
    ) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canCreateDirectories = false
        panel.prompt = "Upload"
        panel.message = BrowserPageOrigin.uploadMessage(
            from: Self.name(of: frame.securityOrigin),
            allowsMultiple: parameters.allowsMultipleSelection
        )
        guard await panel.present() == .OK else { return nil }
        return panel.urls
    }

    private static func name(of origin: WKSecurityOrigin) -> String? {
        BrowserPageOrigin.name(scheme: origin.protocol, host: origin.host, port: origin.port)
    }
}
