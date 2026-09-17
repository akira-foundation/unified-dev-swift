import AppKit
import Core
import QuartzCore

@MainActor
protocol TranscriptHoldDelegate: AnyObject {
    func holdEnded()
    var reducesMotion: Bool { get }
}

final class TranscriptHoldView: NSView {
    let scroll: NSScrollView
    weak var delegate: TranscriptHoldDelegate?

    private(set) var isHolding = false
    private var letGo: Task<Void, Never>?

    private static let fadeKey = "unifieddev.transcript.reveal"

    init(scroll: NSScrollView) {
        self.scroll = scroll
        super.init(frame: .zero)
        wantsLayer = true
        autoresizesSubviews = false
        addSubview(scroll)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not in a nib") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isHolding ? nil : super.hitTest(point)
    }

    override func layout() {
        super.layout()
        scroll.frame = bounds
    }

    func hold() {
        if isHolding {
            armLetGo()
            return
        }
        isHolding = true
        scroll.alphaValue = 0
        TranscriptHoldCensus.arrived()
        armLetGo()
    }

    func ready() {
        letGo?.cancel()
        letGo = nil
        guard isHolding else { return }
        isHolding = false
        fading {
            needsLayout = true
            layoutSubtreeIfNeeded()
            scroll.alphaValue = 1
            delegate?.holdEnded()
        }
        TranscriptHoldCensus.revealed()
    }

    private func armLetGo() {
        letGo?.cancel()
        letGo = Task { @MainActor [weak self] in
            try? await Task.sleep(for: TranscriptPaneHold.arrival)
            guard !Task.isCancelled else { return }
            self?.ready()
        }
    }

    private func fading(_ change: () -> Void) {
        let seconds = delegate?.reducesMotion == true ? 0 : Motion.revealSeconds
        if seconds > 0 {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = seconds
            layer?.add(fade, forKey: Self.fadeKey)
        }
        change()
    }
}
