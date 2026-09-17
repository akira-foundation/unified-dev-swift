import AppKit
import Foundation
import Observation
import WebKit
import Core

@MainActor
@Observable
final class BrowserSession {
    let webView: BrowserPageWebView

    let pageView = BrowserHostView()

    var viewport = BrowserViewport()

    private(set) var canGoBack = false
    private(set) var canGoForward = false
    private(set) var isLoading = false
    private(set) var loadProgress: Double = 0
    private(set) var currentURL: URL?
    private(set) var failure: BrowserLoadFailure?
    private(set) var page = BrowserTabTitle.BrowserPage()

    @ObservationIgnored private let navigation = NavigationObserver()
    @ObservationIgnored private let ui = BrowserUIObserver()

    @ObservationIgnored var host = BrowserPaneHost()

    @ObservationIgnored private var popups = BrowserPopups()

    @ObservationIgnored private var dialogs = BrowserDialogs()
    @ObservationIgnored private let dialogPresenter = BrowserDialogPresenter()

    @ObservationIgnored private var downloadLimit = BrowserDownloads()

    private(set) var downloads: [BrowserDownloadItem] = []

    private(set) var find = BrowserFind()

    @ObservationIgnored private var iconRequest: Task<Void, Never>?

    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    @ObservationIgnored private let root: String

    init(url: String, root: String = "") {
        self.root = root
        Self.preferInspectorDocked()
        let configuration = WKWebViewConfiguration()
        Self.enableDeveloperExtras(on: configuration.preferences)
        webView = BrowserPageWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        pageView.attach(webView)
        webView.underPageBackgroundColor = .clear
        navigation.owner = self
        webView.navigationDelegate = navigation
        ui.owner = self
        webView.uiDelegate = ui
        webView.findCommand = { [weak self] command in self?.perform(command) }
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] view, _ in
                MainActor.assumeIsolated {
                    self?.adopt(BrowserTabTitle.BrowserPage(title: view.title ?? ""))
                }
            },
            webView.observe(\.url) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            webView.observe(\.canGoBack) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            webView.observe(\.canGoForward) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            webView.observe(\.isLoading) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            webView.observe(\.estimatedProgress) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
        ]
        currentURL = BrowserAddress.url(from: url)
        page = BrowserTabTitle.BrowserPage(address: displayAddress)
        load(url)
    }

    func load(_ text: String) {
        if let file = LocalPage.fileURL(from: text, root: root) {
            webView.loadFileURL(
                file, allowingReadAccessTo: URL(filePath: root, directoryHint: .isDirectory)
            )
            return
        }
        guard let url = BrowserAddress.url(from: text) else { return }
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    var backHistory: [BrowserToolbar.HistoryEntry] {
        BrowserToolbar.backMenu(webView.backForwardList.backList.map(Self.page))
    }

    var forwardHistory: [BrowserToolbar.HistoryEntry] {
        BrowserToolbar.forwardMenu(webView.backForwardList.forwardList.map(Self.page))
    }

    func go(back distance: Int) {
        guard let item = webView.backForwardList.item(at: distance) else { return }
        webView.go(to: item)
    }

    private static func page(_ item: WKBackForwardListItem) -> BrowserTabTitle.BrowserPage {
        BrowserTabTitle.BrowserPage(address: item.url.absoluteString, title: item.title ?? "")
    }

    func reload() {
        if let origin = BrowserFavicon.origin(of: displayAddress) {
            BrowserFaviconStore.shared.forget(origin)
        }
        if webView.url == nil, let url = currentURL {
            webView.load(URLRequest(url: url))
        } else {
            webView.reload()
        }
    }

    func snapshot(width: Double? = nil) async throws -> Data {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(value: width ?? Double(webView.bounds.width))

        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        else {
            throw BrowserSnapshotFailure()
        }
        return png
    }

    func text() async throws -> String {
        let value = try await evaluate(.visibleText) { $0 as? String }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func scroll(_ scroll: BrowserScroll) async throws -> (offset: Int, height: Int, viewport: Int) {
        try await evaluate(.scroll(scroll)) { value in
            guard let numbers = value as? [Double], numbers.count == 3 else { return nil }
            return (Int(numbers[0]), Int(numbers[1]), Int(numbers[2]))
        }
    }

    private func evaluate<Value: Sendable>(
        _ script: BrowserPageScript,
        reading read: @escaping @Sendable (Any?) -> Value?
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script.source) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let read = read(value) {
                    continuation.resume(returning: read)
                } else {
                    continuation.resume(throwing: BrowserScriptFailure())
                }
            }
        }
    }

    fileprivate func findIcon() {
        guard let origin = BrowserFavicon.origin(of: displayAddress),
              BrowserFaviconStore.shared.claim(origin)
        else { return }

        iconRequest?.cancel()
        iconRequest = Task { [weak self] in await self?.findIcon(for: origin) }
    }

    private func findIcon(for origin: String) async {
        for delay in BrowserFavicon.attempts {
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            guard BrowserFavicon.origin(of: displayAddress) == origin else { return }

            let links = await iconLinks()
            guard let choice = BrowserFavicon.choose(from: links) else { continue }

            guard let answer = await iconImage(at: choice.index),
                  answer.href == links[choice.index].href,
                  let png = BrowserFavicon.read(answer.dataURL)
            else { return }

            BrowserFaviconStore.shared.adopt(png, for: origin)
            return
        }
    }

    private func iconLinks() async -> [BrowserFaviconLink] {
        let value: Any? = try? await webView.callAsyncJavaScript(
            BrowserFaviconScript.links,
            arguments: [
                "limit": BrowserFavicon.linkLimit,
                "chars": BrowserFavicon.textLimit,
            ],
            contentWorld: .defaultClient
        )
        return BrowserFavicon.links(from: value as? [String] ?? [])
    }

    private func iconImage(at index: Int) async -> (href: String, dataURL: String)? {
        let value: Any? = try? await webView.callAsyncJavaScript(
            BrowserFaviconScript.image,
            arguments: [
                "index": index,
                "size": BrowserFavicon.pixels,
                "chars": BrowserFavicon.textLimit,
                "timeout": BrowserFavicon.loadTimeout,
            ],
            contentWorld: .defaultClient
        )
        guard let pair = value as? [String], pair.count == 2 else { return nil }
        return (href: pair[0], dataURL: pair[1])
    }

    func openWindow(_ url: URL?) {
        switch popups.request(url) {
        case .open(let url):
            host.openTab(url)
        case .refuse:
            break
        case .refuseAndSay(let notice):
            host.report(notice)
        }
    }

    func ask(
        _ kind: BrowserDialogs.Kind,
        message: String,
        defaultText: String = "",
        from name: String?
    ) async -> BrowserDialogAnswer {
        switch dialogs.request(kind, message: message, defaultText: defaultText, from: name) {
        case .suppress:
            return .dismissed
        case .show(let presentation):
            let answer = await dialogPresenter.ask(kind, presentation, over: webView.window)
            if answer.isSilenced { dialogs.silence() }
            return answer
        }
    }

    fileprivate func pageCommitted() {
        dialogs.pageCommitted()
    }

    fileprivate func record(_ error: any Error) {
        let error = error as NSError
        let host = (error.userInfo[NSURLErrorFailingURLErrorKey] as? URL)?.host()
        failure = BrowserLoadFailure.of(domain: error.domain, code: error.code, host: host)
    }

    fileprivate func clearFailure() {
        if failure != nil { failure = nil }
    }

    func perform(_ command: BrowserFindCommand) {
        switch command {
        case .show: find.show()
        case .next: step(backwards: false)
        case .previous: step(backwards: true)
        case .hide: find.hide()
        }
    }

    func typeInFind(_ text: String) {
        find.type(text)
        step(backwards: false)
    }

    private func step(backwards: Bool) {
        guard find.canStep else { return find.settle(matched: false) }

        let query = find.query
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = find.isCaseSensitive
        configuration.wraps = true

        Task { [weak self] in
            guard let self else { return }
            let result = try? await webView.find(query, configuration: configuration)
            guard find.query == query else { return }
            find.settle(matched: result?.matchFound ?? false)
        }
    }

    func begin(_ download: WKDownload) {
        switch downloadLimit.request(from: pageName) {
        case .save:
            let item = BrowserDownloadItem(download)
            downloads.append(item)
            download.delegate = item
        case .refuse:
            download.cancel { _ in }
        case .refuseAndSay(let notice):
            download.cancel { _ in }
            host.report(notice)
        }
    }

    func clearDownloads() {
        downloads.removeAll { $0.state != .running }
    }

    private var pageName: String? {
        guard let url = webView.url ?? currentURL, let host = url.host() else { return nil }
        return BrowserPageOrigin.name(scheme: url.scheme ?? "", host: host, port: url.port ?? 0)
    }

    func stop() {
        observations = []
        iconRequest?.cancel()
        iconRequest = nil
        dialogPresenter.dismiss()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        host = BrowserPaneHost()
        pageView.removeFromSuperview()
    }

    var displayAddress: String {
        currentURL?.absoluteString ?? ""
    }

    private func adopt(_ page: BrowserTabTitle.BrowserPage) {
        let next = BrowserTabTitle.advance(from: self.page, to: page)
        guard next != self.page else { return }
        self.page = next
    }

    fileprivate func refresh() {
        if canGoBack != webView.canGoBack { canGoBack = webView.canGoBack }
        if canGoForward != webView.canGoForward { canGoForward = webView.canGoForward }
        if isLoading != webView.isLoading { isLoading = webView.isLoading }
        let progress = (webView.estimatedProgress * 100).rounded() / 100
        if loadProgress != progress { loadProgress = progress }
        if let url = webView.url, url != currentURL { currentURL = url }
        adopt(BrowserTabTitle.BrowserPage(address: displayAddress))
    }

    private static func enableDeveloperExtras(on preferences: WKPreferences) {
        guard preferences.responds(to: NSSelectorFromString("_setDeveloperExtrasEnabled:")) else {
            return
        }
        preferences.setValue(true, forKey: "developerExtrasEnabled")
    }

    private static let startsAttachedKey =
        "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached"

    private static var hasAskedForDockedInspector = false

    private static func preferInspectorDocked() {
        guard !hasAskedForDockedInspector else { return }
        hasAskedForDockedInspector = true
        UserDefaults.standard.set(true, forKey: startsAttachedKey)
    }
}

private final class NavigationObserver: NSObject, WKNavigationDelegate {
    weak var owner: BrowserSession?

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        owner?.refresh()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        owner?.clearFailure()
        owner?.refresh()
        owner?.pageCommitted()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        owner?.refresh()
        owner?.findIcon()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        owner?.record(error)
        owner?.refresh()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        owner?.record(error)
        owner?.refresh()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        navigationAction.shouldPerformDownload ? .download : .allow
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        navigationResponse.canShowMIMEType ? .allow : .download
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        owner?.begin(download)
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        owner?.begin(download)
    }
}

struct BrowserSnapshotFailure: LocalizedError {
    var errorDescription: String? { "Unified Dev could not turn this page into an image." }
}

struct BrowserScriptFailure: LocalizedError {
    var errorDescription: String? {
        "That page did not answer. It may have navigated while Unified Dev was reading it."
    }
}
