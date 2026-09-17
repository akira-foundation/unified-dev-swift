import SwiftUI
import AppKit

struct NoticeDrainBar: NSViewRepresentable {
    var fraction: Double
    var remaining: Duration?
    var generation: Int
    var tint: Color = Palette.accent

    func makeNSView(context: Context) -> NoticeDrainBarView { NoticeDrainBarView() }

    func updateNSView(_ view: NoticeDrainBarView, context: Context) {
        view.tint = NSColor(tint)
        view.apply(fraction: fraction, remaining: remaining, generation: generation)
    }
}

final class NoticeDrainBarView: NSView {
    private let track = CALayer()
    private let bar = CALayer()
    private var generation = -1
    private var fraction: Double = 1
    private var remaining: Duration?
    var tint: NSColor = Palette.accentNSColor {
        didSet { if tint != oldValue { applyColours() } }
    }

    private static let frameRate = CAFrameRateRange(minimum: 10, maximum: 24, preferred: 20)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(bar)
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        track.anchorPoint = CGPoint(x: 0, y: 0.5)
        applyColours()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [track, bar] {
            layer.bounds = CGRect(origin: .zero, size: bounds.size)
            layer.position = CGPoint(x: 0, y: bounds.midY)
        }
        CATransaction.commit()
        if bar.animation(forKey: "drain") == nil { restate() }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColours()
    }

    func apply(fraction: Double, remaining: Duration?, generation: Int) {
        guard generation != self.generation else { return }
        self.generation = generation
        self.fraction = min(max(fraction, 0), 1)
        self.remaining = remaining
        restate()
    }

    private func restate() {
        bar.removeAnimation(forKey: "drain")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.transform = CATransform3DMakeScale(fraction, 1, 1)
        CATransaction.commit()

        guard let remaining, remaining > .zero, bounds.width > 0 else { return }
        let drain = CABasicAnimation(keyPath: "transform.scale.x")
        drain.fromValue = fraction
        drain.toValue = 0
        drain.duration = remaining.seconds
        drain.timingFunction = CAMediaTimingFunction(name: .linear)
        drain.fillMode = .forwards
        drain.isRemovedOnCompletion = false
        drain.preferredFrameRateRange = Self.frameRate
        bar.add(drain, forKey: "drain")
    }

    private func applyColours() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let accent = tint
            track.backgroundColor = accent.withAlphaComponent(0.10).cgColor
            bar.backgroundColor = accent.withAlphaComponent(0.6).cgColor
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

extension Duration {
    var seconds: CFTimeInterval {
        CFTimeInterval(components.seconds) + CFTimeInterval(components.attoseconds) / 1e18
    }
}
