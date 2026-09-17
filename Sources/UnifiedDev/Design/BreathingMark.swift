import SwiftUI
import AppKit
import QuartzCore
import Core

struct BreathingMark<Content: View>: View {
    var isMoving = true

    @ViewBuilder var content: () -> Content

    private var pulse: BusyPulse { .shared }

    var body: some View {
        if isMoving && pulse.isTicking {
            BreathingMarkHost(epoch: pulse.epoch, content: content())
        } else {
            content()
        }
    }
}

private struct BreathingMarkHost<Content: View>: NSViewRepresentable {
    var epoch: CFTimeInterval

    var content: Content

    func makeNSView(context: Context) -> BreathingMarkView<Content> {
        let view = BreathingMarkView(content: content)
        view.configure(epoch: epoch, content: content)
        return view
    }

    func updateNSView(_ view: BreathingMarkView<Content>, context: Context) {
        view.configure(epoch: epoch, content: content)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize, nsView: BreathingMarkView<Content>, context: Context
    ) -> CGSize? {
        nsView.fittingSize
    }
}

final class BreathingMarkView<Content: View>: BusyPulseLayerView {
    private let hosting: NSHostingView<Content>
    private var epoch: CFTimeInterval = 0

    init(content: Content) {
        hosting = NSHostingView(rootView: content)
        super.init(frame: .zero)
        layer?.masksToBounds = false
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize { hosting.intrinsicContentSize }

    func configure(epoch: CFTimeInterval, content: Content) {
        hosting.rootView = content
        guard epoch != self.epoch else { return }
        self.epoch = epoch
        install()
    }

    private func install() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.opacity = Float(BusyBreath.restingOpacity)
        CATransaction.commit()

        guard let layer else { return }
        install(breath(), on: layer, key: "breathe", beginAt: epoch)
    }

    private func breath() -> CAKeyframeAnimation {
        let samples = BusyBreath.opacitySamples(count: 24)
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = samples
        animation.keyTimes = (0..<samples.count).map {
            NSNumber(value: Double($0) / Double(samples.count - 1))
        }
        animation.calculationMode = .linear
        animation.duration = BusyBreath.period
        animation.preferredFrameRateRange = CAFrameRateRange(minimum: 8, maximum: 15, preferred: 12)
        return animation
    }
}
