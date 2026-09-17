import AppKit
import QuartzCore

@MainActor
final class FrameRecorder {
    private var link: CADisplayLink?
    private let view: NSView
    private let observe: () -> CGFloat
    private var last: CFTimeInterval = 0
    private(set) var intervals: [Double] = []
    private(set) var widths: [CGFloat] = []
    private var isRecording = false

    init(view: NSView, observe: @escaping () -> CGFloat) {
        self.view = view
        self.observe = observe
    }

    func start() {
        intervals.removeAll()
        widths.removeAll()
        last = 0
        isRecording = true
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        isRecording = false
        link?.invalidate()
        link = nil
    }

    @objc private func tick() {
        guard isRecording else { return }
        let now = CACurrentMediaTime()
        widths.append(observe())
        defer { last = now }
        guard last != 0 else { return }
        intervals.append(now - last)
    }
}
