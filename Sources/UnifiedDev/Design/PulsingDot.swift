import SwiftUI
import QuartzCore
import Core

struct PulsingDot: View {
    var diameter: CGFloat

    var tint: Color

    var isMoving = true

    private var pulse: BusyPulse { .shared }

    var body: some View {
        if isMoving && pulse.isTicking {
            PulsingDotLayer(epoch: pulse.epoch, diameter: diameter, tint: NSColor(tint))
                .frame(width: diameter, height: diameter)
        } else {
            Circle()
                .fill(tint.opacity(BusyDot.opacity(at: BusyDot.resting)))
                .frame(
                    width: diameter * BusyDot.scale(at: BusyDot.resting),
                    height: diameter * BusyDot.scale(at: BusyDot.resting)
                )
        }
    }
}

struct ActivityDot: View {
    var isActive: Bool
    var tint: Color = Palette.running

    var body: some View {
        PulsingDot(
            diameter: Metrics.dot,
            tint: isActive ? tint : Palette.textTertiary,
            isMoving: isActive
        )
    }
}

private struct PulsingDotLayer: NSViewRepresentable {
    var epoch: CFTimeInterval

    var diameter: CGFloat

    var tint: NSColor

    func makeNSView(context: Context) -> PulsingDotView {
        let view = PulsingDotView(frame: .zero)
        view.configure(epoch: epoch, diameter: diameter, tint: tint)
        return view
    }

    func updateNSView(_ view: PulsingDotView, context: Context) {
        view.configure(epoch: epoch, diameter: diameter, tint: tint)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PulsingDotView, context: Context) -> CGSize? {
        CGSize(width: diameter, height: diameter)
    }
}

final class PulsingDotView: BusyPulseLayerView {
    private static let frameRate = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 12)

    private let dot = CAShapeLayer()
    private var epoch: CFTimeInterval = 0
    private var diameter: CGFloat = 0
    private var tint: NSColor = .clear

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layer?.masksToBounds = false
        dot.strokeColor = nil
        dot.bounds = .zero
        layer?.addSublayer(dot)
    }

    override func layout() {
        super.layout()
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.position = centre
        CATransaction.commit()
    }

    override func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        dot.fillColor = resolved(tint)
        CATransaction.commit()
    }

    func configure(epoch: CFTimeInterval, diameter: CGFloat, tint: NSColor) {
        if tint != self.tint {
            self.tint = tint
            applyColors()
        }
        if diameter != self.diameter {
            self.diameter = diameter
            rebuildPath()
        }
        guard epoch != self.epoch else { return }
        self.epoch = epoch
        install()
    }

    private func rebuildPath() {
        let radius = diameter * BusyDot.drawnScale / 2
        dot.path = CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    private func install() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let resting = BusyDot.pathScale(at: BusyDot.resting)
        dot.transform = CATransform3DMakeScale(resting, resting, 1)
        dot.opacity = Float(BusyDot.opacity(at: BusyDot.resting))
        CATransaction.commit()

        install(
            pulse(
                "transform.scale",
                from: BusyDot.pathScale(at: 0), to: BusyDot.pathScale(at: 1),
                period: BusyDot.period, frameRate: Self.frameRate
            ),
            on: dot, key: "swell", beginAt: epoch
        )
        install(
            pulse(
                "opacity",
                from: BusyDot.opacity(at: 0), to: BusyDot.opacity(at: 1),
                period: BusyDot.period, frameRate: Self.frameRate
            ),
            on: dot, key: "fade", beginAt: epoch
        )
    }
}
