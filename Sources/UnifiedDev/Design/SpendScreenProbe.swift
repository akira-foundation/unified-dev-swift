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
        let made: [(String, Screen)]
        do {
            made = try await screens()
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
        var written = 0
        var wanted = 0
        for (name, screen) in made {
            for scheme in [ColorScheme.light, .dark] {
                wanted += 1
                if await shoot(screen, scheme: scheme, named: "\(name)-\(scheme)") { written += 1 }
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(wanted)\n".utf8))
        exit(written == wanted ? 0 : 1)
    }

    private static let size = CGSize(width: 900, height: 1900)

    private typealias Screen = (board: SpendBoard, accounts: [SpendAccountLine])

    private static func shoot(_ screen: Screen, scheme: ColorScheme, named name: String) async -> Bool {
        let host = NSHostingController(rootView: SpendScreenBody(
            board: screen.board, accounts: .read(screen.accounts), span: .constant(.week)
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

    private static func screens() async throws -> [(String, Screen)] {
        var made: [(String, Screen)] = []
        for scenario in Scenario.allCases {
            let world = try SpendProbeWorld(at: directory + "/world-" + scenario.rawValue)
            try await scenario.populate(world)
            try await world.index()
            made.append((scenario.rawValue, try await world.screen()))
        }
        return made
    }

    private enum Scenario: String, CaseIterable {
        case noAccounts
        case empty
        case one
        case two
        case history

        func populate(_ world: SpendProbeWorld) async throws {
            let claude = try world.defaultHome(.claudeCode)
            let codex = try world.defaultHome(.codex)
            try world.signIn(claude, as: "ada@home.example")
            try world.signIn(codex, as: "ada@home.example")
            guard self != .empty else { return }
            try Self.week(in: claude, world: world)
            let today = Calendar.current.startOfDay(for: Date())
            try world.claude(250_000, in: claude, project: "lantern", on: today, as: "default-lantern")
            try world.codex(200_000, in: codex, project: "billing", on: today, as: "default-billing")
            switch self {
            case .noAccounts, .empty:
                break
            case .one:
                let client = try await world.createAccount(.claudeCode, label: "Client")
                try world.signIn(client, as: "ada@client.example")
                try world.claude(900_000, in: client, project: "billing", on: today, as: "client-billing")
            case .two:
                let client = try await world.createAccount(.claudeCode, label: "Client")
                try world.signIn(client, as: "ada@client.example")
                try world.claude(900_000, in: client, project: "billing", on: today, as: "client-billing")
                let side = try await world.createAccount(.codex, label: "Side project")
                try world.codex(150_000, in: side, project: "lantern", on: today, as: "side-lantern")
            case .history:
                let first = try await world.createAccount(.claudeCode, label: "Client")
                try world.signIn(first, as: "ada@before.example")
                try world.claude(150_000, in: first, project: "billing", on: today, as: "before-billing")
                let oldCodex = try await world.createAccount(.codex, label: "Old codex")
                try world.codex(60_000, in: oldCodex, project: "billing", on: today, as: "old-codex")
                try await world.index()
                try await world.removeAccount(first)
                try await world.removeAccount(oldCodex)
                let client = try await world.createAccount(.claudeCode, label: "Client")
                try world.signIn(client, as: "ada@client.example")
                try world.claude(900_000, in: client, project: "billing", on: today, as: "client-billing")
            }
        }

        private static func week(in account: AgentAccountHome, world: SpendProbeWorld) throws {
            let today = Calendar.current.startOfDay(for: Date())
            let shape: [Int] = [2_000, 4_000, 10_000, 20_000, 60_000, 140_000, 600_000]
            for (offset, output) in shape.enumerated() {
                guard let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: today) else { continue }
                try world.claude(
                    output, in: account, project: offset.isMultiple(of: 2) ? "billing" : "lantern",
                    on: day, as: "default-day-\(offset)"
                )
            }
        }
    }
}
#endif
