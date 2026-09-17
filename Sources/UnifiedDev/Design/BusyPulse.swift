import SwiftUI
import QuartzCore
import Core

@MainActor
@Observable
final class BusyPulse {
    static let shared = BusyPulse()

    private(set) var isTicking = false

    private(set) var epoch: CFTimeInterval = 0

    private init() {}

    func setTicking(_ wanted: Bool) {
        guard wanted != isTicking else { return }
        if wanted { epoch = CACurrentMediaTime() }
        isTicking = wanted
    }
}

struct BusyPulseDriver: ViewModifier {
    let app: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let isAskRunning = app.askStatus == .running
        let wanted = (!app.runningWorkspaceIDs.isEmpty || isAskRunning) && !reduceMotion

        return content.onChange(of: wanted, initial: true) { _, on in
            BusyPulse.shared.setTicking(on)
        }
    }
}

extension View {
    func runsBusyPulse(_ app: AppModel) -> some View {
        modifier(BusyPulseDriver(app: app))
    }
}

class BusyPulseLayerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }

    override var wantsUpdateLayer: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
    }

    func applyColors() {}

    final func resolved(_ color: NSColor) -> CGColor {
        var answer = color.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            answer = color.cgColor
        }
        return answer
    }

    final func install(_ animation: CAAnimation, on target: CALayer, key: String, beginAt: CFTimeInterval) {
        animation.beginTime = target.convertTime(beginAt, from: nil)
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.fillMode = .both
        target.removeAnimation(forKey: key)
        target.add(animation, forKey: key)
    }

    final func pulse(
        _ keyPath: String,
        from: Double,
        to: Double,
        period: TimeInterval,
        frameRate: CAFrameRateRange
    ) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = period / 2
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.autoreverses = true
        animation.preferredFrameRateRange = frameRate
        return animation
    }
}
