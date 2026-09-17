import SwiftUI
import QuartzCore
import Core

struct ActivityRule: View {
    var variant: BusyRuleVariant = .live

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pulse: BusyPulse { .shared }

    private var isRunning: Bool {
        switch app.selection {
        case .ask: app.ask.isRunning
        case .home: false
        default: app.selection.workspaceID.map(app.runningWorkspaceIDs.contains) ?? false
        }
    }

    var body: some View {
        ActivityRuleFigure(variant: variant, isMoving: pulse.isTicking)
            .opacity(isRunning ? 1 : 0)
            .animation(reduceMotion ? nil : Motion.pane, value: isRunning)
            .allowsHitTesting(false)
    }
}

struct ActivityRuleFigure: View {
    var variant: BusyRuleVariant
    var isMoving: Bool

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if isMoving {
            MovingActivityRule(variant: variant, epoch: BusyPulse.shared.epoch)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            StillActivityRule(variant: variant)
        }
    }
}

private struct StillActivityRule: View {
    var variant: BusyRuleVariant

    var body: some View {
        switch variant {
        case .crest:
            ZStack(alignment: .bottomTrailing) {
                track
                crest(BusyCrest.stops()).frame(width: BusyCrest.length)
            }
        case .current:
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    track
                    crest(BusyCrest.waveStops(
                        wavelengths: BusyCrest.wavelengths(alongWidth: geometry.size.width)
                    ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        case .swell:
            Rectangle()
                .fill(Palette.running)
                .opacity(BusyRule.opacity(at: BusyRule.resting))
                .frame(maxWidth: .infinity)
                .frame(height: BusyRule.restingHeight)
        }
    }

    private var track: some View {
        Rectangle()
            .fill(Palette.running)
            .opacity(BusyCrest.trackOpacity)
            .frame(maxWidth: .infinity)
            .frame(height: BusyRule.restingHeight)
    }

    private func crest(_ stops: [BusyCrest.Stop]) -> some View {
        VStack(spacing: 0) {
            band(stops, scale: BusyCrest.glowShare, height: BusyCrest.glowHeight)
            band(stops, scale: 1, height: BusyRule.restingHeight)
        }
        .frame(height: BusyCrest.thickness)
    }

    private func band(_ stops: [BusyCrest.Stop], scale: Double, height: Double) -> some View {
        LinearGradient(
            stops: stops.map {
                Gradient.Stop(
                    color: Palette.running.opacity($0.opacity * scale),
                    location: CGFloat($0.location)
                )
            },
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: height)
    }
}

private struct MovingActivityRule: NSViewRepresentable {
    var variant: BusyRuleVariant
    var epoch: CFTimeInterval

    func makeNSView(context: Context) -> ActivityRuleView {
        let view = ActivityRuleView(frame: .zero)
        view.configure(variant: variant, epoch: epoch)
        return view
    }

    func updateNSView(_ view: ActivityRuleView, context: Context) {
        view.configure(variant: variant, epoch: epoch)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize, nsView: ActivityRuleView, context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }
}

final class ActivityRuleView: BusyPulseLayerView {
    private static let travelFrameRate = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)

    private static let fadeFrameRate = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 24)

    private let track = CALayer()
    private let core = CAGradientLayer()
    private let glow = CAGradientLayer()

    private var variant: BusyRuleVariant = .live
    private var epoch: CFTimeInterval?
    private var laidOutWidth: CGFloat = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for gradient in [glow, core] {
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
        }
        layer?.addSublayer(track)
        layer?.addSublayer(glow)
        layer?.addSublayer(core)
        applyColors()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let bottom = bounds.height
        track.frame = CGRect(
            x: 0,
            y: bottom - CGFloat(BusyRule.restingHeight),
            width: bounds.width,
            height: CGFloat(BusyRule.restingHeight)
        )
        let width = figureWidth
        core.bounds = CGRect(x: 0, y: 0, width: width, height: CGFloat(BusyRule.restingHeight))
        glow.bounds = CGRect(x: 0, y: 0, width: width, height: CGFloat(BusyCrest.glowHeight))
        core.position = CGPoint(x: restingCentre, y: bottom - CGFloat(BusyRule.restingHeight) / 2)
        glow.position = CGPoint(
            x: restingCentre,
            y: bottom - CGFloat(BusyRule.restingHeight) - CGFloat(BusyCrest.glowHeight) / 2
        )
        CATransaction.commit()

        guard bounds.width != laidOutWidth else { return }
        laidOutWidth = bounds.width
        applyColors()
        install()
    }

    private var figureWidth: CGFloat {
        switch variant {
        case .crest:
            CGFloat(BusyCrest.length)
        case .current:
            CGFloat(BusyCrest.wavelengths(alongWidth: bounds.width)) * CGFloat(BusyCrest.waveLength)
        case .swell:
            bounds.width
        }
    }

    private var restingCentre: CGFloat {
        switch variant {
        case .crest: CGFloat(BusyCrest.restingCentre(alongWidth: bounds.width))
        case .current, .swell: figureWidth / 2
        }
    }

    override func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let running = resolved(Palette.runningNSColor)
        track.backgroundColor = running.copy(alpha: BusyCrest.trackOpacity) ?? running
        track.isHidden = variant == .swell
        let stops = gradientStops
        apply(stops, scale: 1, to: core, tint: running)
        apply(stops, scale: BusyCrest.glowShare, to: glow, tint: running)
        CATransaction.commit()
    }

    private var gradientStops: [BusyCrest.Stop] {
        switch variant {
        case .crest:
            BusyCrest.stops()
        case .current:
            BusyCrest.waveStops(wavelengths: BusyCrest.wavelengths(alongWidth: bounds.width))
        case .swell:
            [
                BusyCrest.Stop(location: 0, opacity: 1),
                BusyCrest.Stop(location: 1, opacity: 1),
            ]
        }
    }

    private func apply(
        _ stops: [BusyCrest.Stop], scale: Double, to gradient: CAGradientLayer, tint: CGColor
    ) {
        gradient.colors = stops.map { (tint.copy(alpha: $0.opacity * scale) ?? tint) as Any }
        gradient.locations = stops.map { NSNumber(value: $0.location) }
    }

    func configure(variant: BusyRuleVariant, epoch: CFTimeInterval) {
        var changed = false
        if variant != self.variant {
            self.variant = variant
            changed = true
            applyColors()
            needsLayout = true
        }
        if epoch != self.epoch {
            self.epoch = epoch
            changed = true
        }
        guard changed else { return }
        install()
    }

    private func install() {
        guard let epoch else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        core.opacity = variant == .swell ? Float(BusyRule.opacity(at: BusyRule.resting)) : 1
        glow.opacity = variant == .swell ? Float(glowStrength(at: BusyRule.resting)) : 1
        CATransaction.commit()

        switch variant {
        case .crest, .current:
            let range = travel
            for target in [core, glow] {
                install(
                    slide(from: range.lowerBound, to: range.upperBound, period: period),
                    on: target, key: "travel", beginAt: epoch
                )
            }
        case .swell:
            install(
                pulse(
                    "opacity",
                    from: BusyRule.opacity(at: 0), to: BusyRule.opacity(at: 1),
                    period: BusyRule.period, frameRate: Self.fadeFrameRate
                ),
                on: core, key: "travel", beginAt: epoch
            )
            install(
                pulse(
                    "opacity",
                    from: glowStrength(at: 0), to: glowStrength(at: 1),
                    period: BusyRule.period, frameRate: Self.fadeFrameRate
                ),
                on: glow, key: "travel", beginAt: epoch
            )
        }
    }

    private var travel: ClosedRange<CGFloat> {
        switch variant {
        case .crest:
            let range = BusyCrest.travel(alongWidth: bounds.width)
            return CGFloat(range.lowerBound)...CGFloat(range.upperBound)
        case .current, .swell:
            let centre = figureWidth / 2
            return (centre - CGFloat(BusyCrest.waveLength))...centre
        }
    }

    private var period: TimeInterval {
        variant == .crest ? BusyCrest.period : BusyCrest.wavePeriod
    }

    private func glowStrength(at pulse: Double) -> Double {
        let span = BusyRule.peakHeight - BusyRule.restingHeight
        guard span > 0 else { return 0 }
        return (BusyRule.height(at: pulse) - BusyRule.restingHeight) / span * BusyCrest.glowShare
    }

    private func slide(from: CGFloat, to: CGFloat, period: TimeInterval) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = period
        animation.preferredFrameRateRange = Self.travelFrameRate
        return animation
    }
}
