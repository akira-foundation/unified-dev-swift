import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum SpendScreenProbe {
    private static let flag = "--spend-screen-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-spend-screen")
    }

    private static func run() async {
        do {
            try FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true
            )
        } catch {
            FileHandle.standardError.write(Data("\(directory): \(error)\n".utf8))
            exit(1)
        }
        var written = 0
        var wanted = 0
        for (name, input) in inputs() {
            for scheme in [ColorScheme.light, .dark] {
                wanted += 1
                if await shoot(input, scheme: scheme, named: "\(name)-\(scheme)") { written += 1 }
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(wanted)\n".utf8))
        exit(written == wanted ? 0 : 1)
    }

    private static let size = CGSize(width: 900, height: 1900)

    private static func shoot(
        _ input: SpendBoard.Input, scheme: ColorScheme, named name: String
    ) async -> Bool {
        let host = NSHostingController(rootView: SpendScreenBody(
            board: SpendBoard.make(input), accounts: SpendBoard.accounts(input), span: .constant(.week)
        )
            .environment(\.colorScheme, scheme)
            .transaction { $0.disablesAnimations = true }
            .frame(width: size.width, height: size.height))
        host.sizingOptions = []
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = host
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))
        host.view.displayIfNeeded()
        guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return false }
        if host.view.isFlipped {
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
        }
        host.view.layer?.render(in: context.cgContext)
        context.flushGraphics()
        guard let drawn = bitmap.representation(using: .png, properties: [:]) else { return false }
        do {
            try drawn.write(to: URL(filePath: directory + "/" + name + ".png"))
            return true
        } catch {
            FileHandle.standardError.write(Data("\(name): \(error)\n".utf8))
            return false
        }
    }

    private static func inputs() -> [(String, SpendBoard.Input)] {
        [
            ("measured", input(days: week())),
            ("empty", input(days: [])),
            ("accounts", input(days: accountDays(), accounts: accountHomes)),
            ("accounts-removed", input(days: accountDays(), accounts: [accountHomes[0]])),
        ]
    }

    private static let accountHomes = [
        AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountHome.defaultID(for: .claudeCode),
            directory: URL(filePath: "/Users/ada/.claude", directoryHint: .isDirectory),
            isDefault: true
        ),
        AgentAccountHome(
            provider: .claudeCode,
            id: AgentAccountID("work"),
            directory: URL(filePath: "/Users/ada/Library/Application Support/Unified Dev/AgentAccounts/claudeCode/work", directoryHint: .isDirectory),
            isDefault: false
        ),
        AgentAccountHome(
            provider: .codex,
            id: AgentAccountHome.defaultID(for: .codex),
            directory: URL(filePath: "/Users/ada/.codex", directoryHint: .isDirectory),
            isDefault: true
        ),
    ]

    private static func accountDays() -> [SpendDay] {
        let today = Calendar.current.startOfDay(for: Date())
        let transcripts: [(AgentKind, String, String, Int)] = [
            (.claudeCode, "/Users/ada/.claude/projects/-billing/3f1c.jsonl", "claude-opus-5", 600_000),
            (.claudeCode, "/Users/ada/.claude/projects/-lantern/9a2e.jsonl", "claude-opus-5", 250_000),
            (.claudeCode, accountHomes[1].directory.path + "/projects/-billing/71bd.jsonl", "claude-opus-5", 900_000),
            (.codex, "/Users/ada/.codex/sessions/2026/10/rollout-2026-10-20T10-00-00-0a1b2c3d-1111-2222-3333-444455556666.jsonl", "gpt-6-sol", 400_000),
            (.claudeCode, "/Users/ada/Library/Application Support/Unified Dev/AgentAccounts/claudeCode/old/projects/-billing/c0de.jsonl", "claude-opus-5", 150_000),
            (.codex, "/Users/ada/Library/Application Support/Unified Dev/AgentAccounts/codex/old/sessions/rollout-2026-10-19T09-00-00-aaaa1111-2222-3333-4444-555566667777.jsonl", "gpt-6-sol", 80_000),
        ]
        return transcripts.map { provider, file, model, output in
            SpendDay(
                provider: provider,
                day: today,
                model: model,
                directory: "/Users/ada/billing",
                file: file,
                usage: TokenUsage(freshInput: output, cacheRead: output * 20, output: output),
                turns: output / 40_000,
                tier: .base
            )
        }
    }

    private static func input(days: [SpendDay], accounts: [AgentAccountHome] = []) -> SpendBoard.Input {
        SpendBoard.Input(
            days: days,
            accounts: accounts,
            census: SpendCensus(providers: [
                AgentKind.claudeCode.rawValue: SpendProviderCensus(
                    keepsTranscripts: true, files: 400, pending: 0
                ),
                AgentKind.codex.rawValue: SpendProviderCensus(
                    keepsTranscripts: true, files: 90, pending: 90
                ),
            ]),
            installed: [.claudeCode, .codex],
            window: .week
        )
    }

    private static func week() -> [SpendDay] {
        let today = Calendar.current.startOfDay(for: Date())
        let shape: [Double] = [0.002, 0.004, 0.01, 0.02, 0.06, 0.14, 1]
        return shape.enumerated().compactMap { offset, weight in
            guard let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: today)
            else { return nil }
            return SpendDay(
                provider: .claudeCode,
                day: day,
                model: "claude-opus-5",
                directory: offset.isMultiple(of: 2) ? "/Users/ada/billing" : "/Users/ada/lantern",
                file: "/t/\(offset).jsonl",
                usage: TokenUsage(
                    freshInput: Int(weight * 900_000),
                    cacheRead: Int(weight * 1_295_000_000),
                    cacheWriteLong: Int(weight * 13_900_000),
                    output: Int(weight * 6_100_000)
                ),
                turns: Int(weight * 1_500) + 1,
                tier: .base
            )
        }
    }
}
#endif
