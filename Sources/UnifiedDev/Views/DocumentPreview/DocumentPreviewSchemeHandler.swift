import Foundation
import WebKit
import Core

@MainActor
final class DocumentPreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: String
    private let document: String
    var draft: String?
    private var stopped: Set<ObjectIdentifier> = []
    private var running: Set<ObjectIdentifier> = []
    private(set) var served: Set<String> = []

    init(root: String, document: String) {
        self.root = root
        self.document = URL(filePath: document).standardizedFileURL.resolvingSymlinksInPath().path
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        stopped.remove(id)
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        guard let file = DocumentPreview.file(for: url, root: root) else {
            respond(urlSchemeTask, url: url, answer: .refused)
            return
        }
        let draft = file.path == document ? draft : nil
        served.insert(file.path)
        running.insert(id)
        Task {
            let answer = await Task.detached(priority: .userInitiated) {
                DocumentPreviewAnswer.read(file, draft: draft)
            }.value
            self.running.remove(id)
            guard self.stopped.remove(id) == nil else { return }
            self.respond(urlSchemeTask, url: url, answer: answer)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        if running.contains(id) { stopped.insert(id) }
    }

    func forget() {
        served.removeAll()
    }

    private func respond(_ task: any WKURLSchemeTask, url: URL, answer: DocumentPreviewAnswer) {
        let headers = DocumentPreview.responseHeaders(contentType: answer.type, length: answer.body.count)
        guard let response = HTTPURLResponse(
            url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: headers
        ) else {
            task.didFailWithError(URLError(.cannotParseResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(answer.body)
        task.didFinish()
    }
}
