import SwiftUI
import AppKit
import Core

@MainActor
@Observable
final class LoginTerminalSession {
    let label: String

    @ObservationIgnored let terminal: AppTerminalView
    private(set) var isRunning = true

    private let launch: TerminalLaunch
    private var hasStarted = false

    init?(
        executable: String,
        arguments: [String],
        directory: String,
        onExit: @escaping @MainActor (TerminalExit) -> Void
    ) {
        guard let path = Shell.which(executable) else { return nil }

        let variables = Shell.terminalEnvironment(inheriting: Shell.environment())

        label = ([executable] + arguments).joined(separator: " ")
        launch = TerminalLaunch(
            executable: path,
            execName: executable,
            arguments: arguments,
            environment: variables.map { "\($0.key)=\($0.value)" }.sorted(),
            directory: FileManager.default.fileExists(atPath: directory)
                ? directory
                : AgentScratchDirectory.current()
        )

        terminal = AppTerminalView(frame: .zero)
        terminal.onExit = { [weak self] exit in
            guard let self, self.isRunning else { return }
            self.isRunning = false
            onExit(exit)
        }
    }

    func start() {
        guard !hasStarted, isRunning else { return }
        hasStarted = true
        terminal.start(launch)
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        terminal.shutdown()
    }
}

struct LoginTerminal: NSViewRepresentable {
    let session: LoginTerminalSession

    @AppStorage(TerminalGhostty.defaultsKey) private var usesGhosttyTheme = true
    @AppStorage(TerminalTextSize.defaultsKey) private var fontSize = 0.0

    func makeNSView(context: Context) -> TerminalHostView {
        let host = TerminalHostView()
        host.attach(session.terminal)
        configure()
        session.start()
        return host
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        nsView.attach(session.terminal)
        configure()
        session.start()
    }

    private func configure() {
        session.terminal.usesGhosttyTheme = usesGhosttyTheme
        session.terminal.fontSizeOverride = fontSize > 0 ? CGFloat(fontSize) : nil
    }
}
