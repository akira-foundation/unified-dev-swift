@testable import Core
import Foundation
import Network
import Testing
import WebKit

@MainActor
@Suite("What a previewed document reaches through a peer connection", .serialized, .tags(.security))
struct DocumentPreviewWebRTCTests {
    @Test("ICE gathering against a local STUN listener sends nothing, and local files still load")
    func iceGatheringSendsNothing() async throws {
        let listener = try await LoopbackDatagramListener.start()
        defer { listener.stop() }

        let page = try await Self.open(gatheringAgainst: listener.port, featuresOff: true)
        try await Task.sleep(for: .seconds(3))

        #expect(try await page.evaluate("document.body.dataset.script") == "ran")
        #expect(try await page.evaluate("getComputedStyle(document.body).color") == "rgb(1, 2, 3)")
        #expect(listener.senders == 0)
    }

    @Test("with peer connections left on, the network rules alone let the same page reach the listener")
    func iceGatheringIsSeenWithFeaturesOn() async throws {
        let listener = try await LoopbackDatagramListener.start()
        defer { listener.stop() }

        let page = try await Self.open(gatheringAgainst: listener.port, featuresOff: false)
        let deadline = ContinuousClock.now + .seconds(10)
        while listener.senders == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(try await page.evaluate("document.body.dataset.script") == "ran")
        #expect(listener.senders > 0)
    }

    private static func open(gatheringAgainst port: UInt16, featuresOff: Bool) async throws -> PreviewWebPage {
        let files = [
            "index.html": """
            <!doctype html>
            <html><head><meta charset="utf-8"><link rel="stylesheet" href="style.css"></head>
            <body>loaded<script src="gather.js"></script></body></html>
            """,
            "style.css": "body { color: rgb(1, 2, 3); }",
            "gather.js": """
            document.body.dataset.script = "ran";
            if (typeof RTCPeerConnection === "function") {
                const peer = new RTCPeerConnection({ iceServers: [{ urls: "stun:127.0.0.1:\(port)" }] });
                peer.createDataChannel("probe");
                peer.createOffer().then((offer) => peer.setLocalDescription(offer));
            }
            """,
        ]
        return try await PreviewWebPage.open(files: files) { configuration in
            try await PreviewWebPage.blockNetwork(in: configuration)
            if featuresOff {
                try #require(DocumentPreview.turnOffFeatures(in: configuration.preferences))
            }
        }
    }
}

private final class LoopbackDatagramListener: @unchecked Sendable {
    private let listener: NWListener
    private let lock = NSLock()
    private var seen = 0

    private init(_ listener: NWListener) {
        self.listener = listener
    }

    static func start() async throws -> LoopbackDatagramListener {
        let parameters = NWParameters.udp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let wrapper = LoopbackDatagramListener(try NWListener(using: parameters))
        wrapper.listener.newConnectionHandler = { [wrapper] connection in
            wrapper.lock.withLock { wrapper.seen += 1 }
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

    var senders: Int {
        lock.withLock { seen }
    }

    func stop() {
        listener.cancel()
    }
}
