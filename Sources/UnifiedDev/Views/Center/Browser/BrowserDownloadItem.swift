import AppKit
import CoreServices
import Foundation
import Observation
import WebKit
import Core

@MainActor
@Observable
final class BrowserDownloadItem: NSObject, WKDownloadDelegate, Identifiable {
    enum State: Equatable {
        case running
        case finished
        case failed(String)
    }

    let id = UUID()

    private(set) var name = ""
    private(set) var destination: URL?
    private(set) var state: State = .running
    private(set) var received: Int64 = 0
    private(set) var expected: Int64 = 0

    @ObservationIgnored private var progress: NSKeyValueObservation?

    @ObservationIgnored private var lastFraction = 0.0

    @ObservationIgnored private let source: URL?

    init(_ download: WKDownload) {
        source = download.originalRequest?.url
        super.init()
        watch(download.progress)
    }

    var status: String {
        switch state {
        case .running: BrowserDownloadFile.progress(received: received, expected: expected)
        case .finished: BrowserDownloadFile.size(received)
        case .failed(let reason): reason
        }
    }

    var fraction: Double? {
        guard state == .running, expected > 0 else { return nil }
        return min(Double(received) / Double(expected), 1)
    }

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String
    ) async -> URL? {
        let manager = FileManager.default
        guard let folder = Self.folder(manager) else {
            state = .failed("Unified Dev could not reach your Downloads folder.")
            return nil
        }

        let filename = BrowserDownloadFile.filename(for: suggestedFilename) {
            manager.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
        let url = folder.appendingPathComponent(filename)

        name = filename
        destination = url
        expected = max(response.expectedContentLength, 0)
        return url
    }

    func downloadDidFinish(_ download: WKDownload) {
        progress = nil
        if expected > 0 { received = expected }
        quarantine()
        state = .finished
    }

    func download(_ download: WKDownload, didFailWithError error: any Error, resumeData: Data?) {
        progress = nil
        state = .failed(error.readableMessage)
    }

    private func watch(_ progress: Progress) {
        self.progress = progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            let received = progress.completedUnitCount
            let total = progress.totalUnitCount
            Task { @MainActor [weak self] in
                self?.advance(fraction: fraction, received: received, expected: total)
            }
        }
    }

    private func advance(fraction: Double, received: Int64, expected: Int64) {
        guard state == .running else { return }
        guard fraction - lastFraction >= 0.01 || received == expected else { return }
        lastFraction = fraction
        self.received = received
        if expected > 0 { self.expected = expected }
    }

    private func quarantine() {
        guard var url = destination else { return }
        var values = URLResourceValues()
        values.quarantineProperties = [
            kLSQuarantineTypeKey as String: kLSQuarantineTypeWebDownload,
            kLSQuarantineAgentNameKey as String: "Unified Dev",
            kLSQuarantineDataURLKey as String: source?.absoluteString ?? "",
        ]
        try? url.setResourceValues(values)
    }

    private static func folder(_ manager: FileManager) -> URL? {
        guard let url = manager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return nil
        }
        guard !manager.fileExists(atPath: url.path) else { return url }
        do {
            try manager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return url
    }
}
