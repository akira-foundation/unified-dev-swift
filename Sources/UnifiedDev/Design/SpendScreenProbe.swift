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
        for (name, board) in boards() {
            for scheme in [ColorScheme.light, .dark] {
                wanted += 1
                if await shoot(board, scheme: scheme, named: "\(name)-\(scheme)") { written += 1 }
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(wanted)\n".utf8))
        exit(written == wanted ? 0 : 1)
    }

    private static let size = CGSize(width: 900, height: 760)

    private static func shoot(
        _ board: SpendBoard, scheme: ColorScheme, named name: String
    ) async -> Bool {
        let host = NSHostingController(rootView: SpendScreenBody(board: board, span: .constant(.week))
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

    private static func boards() -> [(String, SpendBoard)] {
        [("measured", board(days: week())), ("empty", board(days: []))]
    }

    private static func board(days: [SpendDay]) -> SpendBoard {
        SpendBoard.make(SpendBoard.Input(
            days: days,
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
        ))
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
