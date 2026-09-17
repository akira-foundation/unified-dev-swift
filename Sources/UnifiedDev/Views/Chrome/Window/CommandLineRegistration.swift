import Core
import Foundation
import Observation

@MainActor
@Observable
final class CommandLineRegistration {
    private(set) var command: String?
    private(set) var isOffered = false

    private let source: @MainActor () -> BridgeAttachment?
    private var run: Task<Void, Never>?

    init(source: @escaping @MainActor () -> BridgeAttachment?) {
        self.source = source
    }

    func resolve() {
        run?.cancel()
        run = Task { [weak self] in
            guard let self else { return }
            guard let attachment = await self.wait() else {
                self.settle(command: nil, isOffered: false)
                return
            }
            let config = await Self.readUserConfig()
            let state = BridgeUserRegistration.state(
                userConfig: config,
                serverNamed: BridgeRegistration.ownerServerName,
                matching: attachment
            )
            guard !Task.isCancelled else { return }
            self.settle(
                command: BridgeRegistration.ownerAddCommand(attachment),
                isOffered: state != .registered
            )
        }
    }

    func cancel() {
        run?.cancel()
        run = nil
    }

    private func settle(command: String?, isOffered: Bool) {
        self.command = command
        self.isOffered = isOffered
        run = nil
    }

    private func wait(timeout: Duration = .seconds(3)) async -> BridgeAttachment? {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let attachment = source() { return attachment }
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return nil }
        }
        return source()
    }

    private static func readUserConfig() async -> Data? {
        await Task.detached(priority: .utility) {
            FileManager.default.contents(atPath: BridgeUserRegistration.userConfigPath)
        }.value
    }
}
