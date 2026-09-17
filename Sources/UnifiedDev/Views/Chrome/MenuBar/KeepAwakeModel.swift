import Foundation
import Core

@MainActor
@Observable
final class KeepAwakeModel {
    static let shared = KeepAwakeModel()

    private(set) var session: KeepAwakeSession?
    @ObservationIgnored private var expiry: Task<Void, Never>?

    private init() {
        session = KeepAwake.load()
    }

    var isActive: Bool { session?.isActive(at: Date()) ?? false }

    var keepsLidClosed: Bool {
        get { UserDefaults.standard.bool(forKey: KeepAwake.lidKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: KeepAwake.lidKey)
            if newValue { SleepSwitch.shared.enable() }
            apply()
        }
    }

    func start(for seconds: TimeInterval?) {
        session = seconds.map { .lasting($0, from: Date()) } ?? .indefinitely(from: Date())
        apply()
    }

    func extend(by seconds: TimeInterval) {
        guard let session, session.isActive(at: Date()) else { return }
        self.session = session.extended(by: seconds, at: Date())
        apply()
    }

    func stop() {
        session = nil
        apply()
    }

    func restore() {
        if let session, !session.isActive(at: Date()) { self.session = nil }
        apply()
    }

    private func apply() {
        KeepAwake.save(session)
        AgentActivity.shared.setKeepAwakeSession(session)
        SleepSwitch.shared.setHoldingLidClosed(KeepAwake.holdsLidClosed(
            session: session, lidEnabled: keepsLidClosed, at: Date()
        ))
        expiry?.cancel()
        expiry = nil
        guard let until = session?.until else { return }
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, until.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }
}
