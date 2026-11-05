import AppKit
import Core
import SwiftUI

#if DEBUG
@MainActor
enum AgentAccountProbe {
    private static let flag = "--agent-account-probe"

    static var isRequested: Bool { CommandLine.arguments.contains(flag) }

    static func runAndExit() -> Never {
        NSApplication.shared.setActivationPolicy(.prohibited)
        Task { await run() }
        RunLoop.main.run()
        exit(1)
    }

    private static var directory: String {
        ProbeHarness.text(flag, or: NSTemporaryDirectory() + "unifieddev-agent-account")
    }

    private static func run() async {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("\(directory): \(error)\n".utf8))
            exit(1)
        }
        var written = 0
        var wanted = 0
        for scene in scenes() {
            for scheme in [ColorScheme.light, .dark] {
                wanted += 1
                if await shoot(scene, scheme: scheme) { written += 1 }
            }
        }
        FileHandle.standardError.write(Data("wrote \(written) of \(wanted)\n".utf8))
        exit(written == wanted ? 0 : 1)
    }

    struct Scene {
        var name: String
        var size: CGSize
        var view: AnyView
    }

    private static func home(_ name: String, _ provider: AgentKind, isDefault: Bool = false) -> AgentAccountHome {
        AgentAccountHome(
            provider: provider,
            id: isDefault ? AgentAccountHome.defaultID(for: provider) : AgentAccountID(name),
            directory: URL(filePath: "/Users/ada/accounts/\(provider.rawValue)/\(name)", directoryHint: .isDirectory),
            isDefault: isDefault
        )
    }

    private static var standings: [AgentAccountStanding] {
        func standing(_ home: AgentAccountHome, email: String?, doubt: String? = nil) -> AgentAccountStanding {
            AgentAccountStanding(
                home: home, identity: AgentAccountIdentity(email: email),
                cliReport: .unanswered, isolationDoubt: doubt
            )
        }
        return [
            standing(home("default", .claudeCode, isDefault: true), email: "ada@home.example"),
            standing(home("work", .claudeCode), email: "ada@client.example"),
            standing(home("default", .codex, isDefault: true), email: nil),
            standing(
                home("lab", .codex), email: "ada@lab.example",
                doubt: "Codex keeps its login in the system keychain here, which a separate directory does not keep apart."
            ),
        ]
    }

    private static func options(
        _ level: AgentAccountOptions.Scope,
        stored: [AgentKind: String] = [:],
        inherited: [AgentKind: String] = [:]
    ) -> AgentAccountOptions {
        let own = stored.mapValues(AgentAccountID.init)
        return AgentAccountOptions.make(
            scope: level,
            choices: AgentAccountChoices(
                workspace: level == .workspace ? own : [:],
                project: level == .project ? own : inherited.mapValues(AgentAccountID.init)
            ),
            standings: standings
        )
    }

    private static func form(_ options: AgentAccountOptions, failure: String? = nil) -> AnyView {
        AnyView(
            Form { AgentAccountRows(options: options, failure: failure, onPick: { _, _ in }) }
                .settingsForm()
                .scrollDisabled(true)
        )
    }

    private static func label(_ choice: AgentAccountChoice, _ provider: AgentKind) -> AnyView {
        let line = AgentAccountLine.make(choice: choice, provider: provider, standings: standings)
        return AnyView(
            VStack(alignment: .leading, spacing: Metrics.gutter) {
                ForEach(0..<2, id: \.self) { index in
                    HStack(spacing: Metrics.spacing) {
                        ComposerControlLabel(
                            systemImage: "slider.horizontal.3", text: "Opus 5 · High", showsMenuIndicator: true
                        )
                        ComposerAccountLabel(line: line, isCompact: index == 1)
                        Spacer()
                    }
                    .padding(Metrics.spacing)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: Metrics.cornerSmall))
                }
                Text(line.sentence)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Metrics.gutter)
        )
    }

    private static func choice(
        _ provider: AgentKind, workspace: String? = nil, project: String? = nil
    ) -> AgentAccountChoice {
        AgentAccountChoice.resolve(
            provider: provider,
            workspace: workspace.map(AgentAccountID.init),
            project: project.map(AgentAccountID.init),
            standings: standings
        )
    }

    private static func scenes() -> [Scene] {
        let form = CGSize(width: 620, height: 300)
        let tall = CGSize(width: 620, height: 340)
        let label = CGSize(width: 520, height: 190)
        return [
            Scene(name: "project-none", size: form, view: Self.form(options(.project))),
            Scene(name: "project-one", size: form, view: Self.form(options(.project, stored: [.claudeCode: "work"]))),
            Scene(name: "project-two", size: tall, view: Self.form(options(.project, stored: [.claudeCode: "work", .codex: "lab"]))),
            Scene(name: "project-doubt", size: tall, view: Self.form(options(.project, stored: [.codex: "lab"]))),
            Scene(name: "project-unavailable", size: tall, view: Self.form(options(.project, stored: [.claudeCode: "deleted"]))),
            Scene(name: "workspace-follows", size: form, view: Self.form(options(.workspace, inherited: [.claudeCode: "work"]))),
            Scene(name: "workspace-one", size: form, view: Self.form(options(.workspace, stored: [.claudeCode: "default.claudeCode"], inherited: [.claudeCode: "work"]))),
            Scene(name: "workspace-two", size: tall, view: Self.form(options(.workspace, stored: [.claudeCode: "default.claudeCode", .codex: "lab"]))),
            Scene(name: "workspace-unavailable", size: tall, view: Self.form(options(.workspace, stored: [.claudeCode: "deleted"], inherited: [.claudeCode: "deleted-too"]))),
            Scene(name: "workspace-failure", size: form, view: Self.form(options(.workspace), failure: "Could not save the account: database is locked")),
            Scene(name: "sheet-two", size: CGSize(width: 440, height: 360), view: Self.form(options(.workspace, stored: [.claudeCode: "default.claudeCode", .codex: "lab"]))),
            Scene(name: "sheet-unavailable", size: CGSize(width: 440, height: 360), view: Self.form(options(.workspace, stored: [.claudeCode: "deleted"], inherited: [.claudeCode: "deleted-too"]))),
            Scene(name: "composer-default", size: label, view: Self.label(choice(.claudeCode), .claudeCode)),
            Scene(name: "composer-project", size: label, view: Self.label(choice(.claudeCode, project: "work"), .claudeCode)),
            Scene(name: "composer-lost", size: label, view: Self.label(choice(.claudeCode, workspace: "deleted", project: "work"), .claudeCode)),
            Scene(name: "composer-both-lost", size: label, view: Self.label(choice(.claudeCode, workspace: "a", project: "b"), .claudeCode)),
            Scene(name: "composer-other-agent", size: label, view: Self.label(choice(.codex, project: "work"), .codex)),
            Scene(name: "composer-no-accounts", size: label, view: Self.label(choice(.cursor, project: "work"), .cursor)),
            Scene(name: "composer-no-accounts-lost", size: label, view: Self.label(choice(.cursor, workspace: "deleted"), .cursor)),
        ] + panelScenes() + offerScenes() + grokUsageScenes()
    }

    private static func shoot(_ scene: Scene, scheme: ColorScheme) async -> Bool {
        let host = NSHostingController(rootView: scene.view
            .environment(\.colorScheme, scheme)
            .background(Palette.surface)
            .transaction { $0.disablesAnimations = true }
            .frame(width: scene.size.width, height: scene.size.height))
        host.sizingOptions = []
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: scene.size),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = host
        host.view.frame = CGRect(origin: .zero, size: scene.size)
        host.view.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(400))
        host.view.displayIfNeeded()
        guard let bitmap = host.view.bitmapImageRepForCachingDisplay(in: host.view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return false }
        if host.view.isFlipped {
            context.cgContext.translateBy(x: 0, y: scene.size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
        }
        host.view.layer?.render(in: context.cgContext)
        context.flushGraphics()
        guard let drawn = bitmap.representation(using: .png, properties: [:]) else { return false }
        let name = "\(scene.name)-\(scheme)"
        do {
            try drawn.write(to: URL(filePath: directory + "/" + name + ".png"))
            return true
        } catch {
            FileHandle.standardError.write(Data("\(name): \(error)\n".utf8))
            return false
        }
    }
}
#endif
