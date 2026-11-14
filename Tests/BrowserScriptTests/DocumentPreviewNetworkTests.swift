import Foundation
import Network
import Testing

@MainActor
@Suite("What a previewed document reaches over the network", .serialized, .tags(.security))
struct DocumentPreviewNetworkTests {
    @Test("a preconnect link, written or added by a script, opens no connection under the preview's rules")
    func preconnectIsBlocked() async throws {
        let listener = try await LoopbackListener.start()
        defer { listener.stop() }

        let page = try await Self.open(preconnectingTo: listener.port, blocked: true)
        try await Task.sleep(for: .seconds(3))

        #expect(try await page.evaluate("document.body.textContent") == "loaded")
        #expect(listener.connections == 0)
    }

    @Test("without the rules the same page does connect, so the test above can see one")
    func preconnectIsSeenWithoutTheRules() async throws {
        let listener = try await LoopbackListener.start()
        defer { listener.stop() }

        let page = try await Self.open(preconnectingTo: listener.port, blocked: false)
        let deadline = ContinuousClock.now + .seconds(10)
        while listener.connections == 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(try await page.evaluate("document.body.textContent") == "loaded")
        #expect(listener.connections > 0)
    }

    private static func open(preconnectingTo port: UInt16, blocked: Bool) async throws -> PreviewWebPage {
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
        return try await PreviewWebPage.open(files: ["index.html": document]) { configuration in
            if blocked {
                try await PreviewWebPage.blockNetwork(in: configuration)
            }
        }
    }
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
