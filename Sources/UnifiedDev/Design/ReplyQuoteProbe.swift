import AppKit
import Core
import SwiftUI

@MainActor
enum ReplyQuoteProbe {
    private static let harness = ProbeHarness(subject: "reply-quote")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    private static let short = "A mensagem ficou em fila."
    private static let long = """
        A mensagem ficou em fila e essa sessão ainda não a leu. Quando ela reportar, \
        mostro-te os números e abro a issue e o PR para develop.
        """

    private static func run() async {
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            await render(name: name, appearance: appearance)
        }
        harness.write(.object(["rendered": .bool(true)]))
        exit(0)
    }

    private static var sheet: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide * 2) {
            SelectionReplyCard(summary: long, agent: AgentKind.claudeCode.label) { _ in }

            ChipFlow(spacing: Metrics.spacingSmall, lineSpacing: Metrics.spacingSmall) {
                ForEach([short, long, long + " " + long], id: \.self) { text in
                    if let quote = ReplyQuote(selection: text) {
                        ReplyQuoteCard(quote: quote, onRemove: {}, onOpen: {})
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 760, alignment: .leading)
        .background(Palette.surface)
    }

    private static func render(name: String, appearance: NSAppearance.Name) async {
        let host = NSHostingView(rootView: sheet)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(200))
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            harness.fail("no bitmap")
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: harness.outputPath + ".\(name).png"))
    }
}
