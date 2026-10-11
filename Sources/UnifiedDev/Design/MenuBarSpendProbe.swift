import AppKit
import Core
import SwiftUI

@MainActor
enum MenuBarSpendProbe {
    private static let harness = ProbeHarness(subject: "menu-bar-spend")
    static var isRequested: Bool { harness.isRequested }
    static func schedule() { Task { @MainActor in await run() } }

    private static func run() async {
        var heights: [String: JSONValue] = [:]
        for (name, board) in boards() {
            heights[name] = .number(Double(await height(of: board)))
        }
        heights["panelGap"] = .number(Double(MenuBarModuleStyle.gap))
        heights["panelWidth"] = .number(Double(MenuBarPanelPlacement.width))
        harness.write(.object(heights))
        exit(0)
    }

    private static func height(of board: SpendBoard) async -> CGFloat {
        let host = NSHostingView(rootView: MenuBarSpendModule(board: board, focus: nil, open: {})
            .frame(width: MenuBarPanelPlacement.width - MenuBarModuleStyle.edge * 2))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: MenuBarPanelPlacement.width, height: 400),
            styleMask: [], backing: .buffered, defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(120))
        return host.fittingSize.height
    }

    private static func boards() -> [(String, SpendBoard)] {
        [
            ("measured", board(days: week(), installed: [.claudeCode, .codex])),
            ("empty", board(days: [], installed: [.claudeCode])),
            ("keepsNoUsage", board(days: week(), installed: [.claudeCode, .codex, .grok])),
        ]
    }

    private static func board(days: [SpendDay], installed: Set<AgentKind>) -> SpendBoard {
        SpendBoard.make(SpendBoard.Input(
            days: days,
            census: SpendCensus(providers: [
                AgentKind.claudeCode.rawValue: SpendProviderCensus(
                    keepsTranscripts: true, files: 400, pending: 0, readAt: Date()
                ),
                AgentKind.codex.rawValue: SpendProviderCensus(
                    keepsTranscripts: true, files: 90, pending: 0, readAt: Date()
                ),
                AgentKind.grok.rawValue: SpendProviderCensus(
                    keepsTranscripts: false, files: 0, pending: 0, readAt: Date()
                ),
            ]),
            installed: installed,
            window: .week
        ))
    }

    private static func week() -> [SpendDay] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: -offset, to: today).map { day in
                SpendDay(
                    provider: offset.isMultiple(of: 3) ? .codex : .claudeCode,
                    day: day,
                    model: offset.isMultiple(of: 3) ? "gpt-6-sol" : "claude-opus-5",
                    directory: "/Users/ada/code/billing",
                    agentSessionID: "session-\(offset)",
                    file: "/t/\(offset).jsonl",
                    usage: TokenUsage(
                        freshInput: 20_000,
                        cacheRead: 400_000_000 / (offset + 1),
                        cacheWriteLong: 9_000_000,
                        output: 1_200_000
                    ),
                    turns: 120
                )
            }
        }
    }
}
