import AppKit
import Core

@MainActor
final class UpdateOfferPresenter {
    private let runningCount: @MainActor () -> Int

    private let isIdle: @MainActor () -> Bool

    private var held: (@MainActor () -> Void)?

    private(set) var heldCheckedAt: Date?

    private var returnIsWaiting = false

    private var returnObserver: NSObjectProtocol?

    private var activationObserver: NSObjectProtocol?

    init(runningCount: @escaping @MainActor () -> Int, isIdle: @escaping @MainActor () -> Bool) {
        self.runningCount = runningCount
        self.isIdle = isIdle
    }

    var isHolding: Bool { held != nil }

    func hold(_ present: @escaping @MainActor () -> Void) {
        held = present
        heldCheckedAt = Date()
        let defaults = UserDefaults.standard
        let recorded = defaults.object(forKey: SoftwareUpdate.offerHeldSinceKey) as? Date
        defaults.set(SoftwareUpdate.holdStart(recorded: recorded, now: Date()), forKey: SoftwareUpdate.offerHeldSinceKey)
        if returnObserver == nil {
            returnObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.presentHeldIfItIsTime(ownerJustReturned: true)
                }
            }
        }
        presentHeldIfItIsTime(ownerJustReturned: false)
    }

    func presentHeldIfItIsTime(ownerJustReturned: Bool) {
        guard let present = held else { return }
        let canShowAlert = NSApp.isActive && NSApp.modalWindow == nil && isIdle()
        let returned = ownerJustReturned || returnIsWaiting
        returnIsWaiting = returned && !canShowAlert
        let moment = SoftwareUpdate.offerMoment(
            runningCount: runningCount(),
            canShowAlert: canShowAlert,
            ownerJustReturned: returned,
            heldSince: UserDefaults.standard.object(forKey: SoftwareUpdate.offerHeldSinceKey) as? Date,
            now: Date()
        )
        guard moment == .present else { return }
        forget()
        present()
    }

    func noteFailedCheck() {
        guard held != nil else { return }
        heldCheckedAt = Date()
    }

    func forget() {
        held = nil
        heldCheckedAt = nil
        returnIsWaiting = false
        UserDefaults.standard.removeObject(forKey: SoftwareUpdate.offerHeldSinceKey)
        if let returnObserver { NotificationCenter.default.removeObserver(returnObserver) }
        returnObserver = nil
    }

    func presentWhenActive(_ present: @escaping @MainActor () -> Void) {
        guard !NSApp.isActive else {
            present()
            return
        }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let observer = self.activationObserver { NotificationCenter.default.removeObserver(observer) }
                self.activationObserver = nil
                present()
            }
        }
    }
}
