import AppKit
import QuartzCore

@MainActor
final class Ticker {
    private var link: CADisplayLink?
    private let view: NSView
    private var last: CFTimeInterval = 0
    private(set) var intervalsMs: [Double] = []

    init(view: NSView) { self.view = view }

    func start() {
        let link = view.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    private(set) var blocksMs: [[Double]] = []
    private var origin: CFTimeInterval = 0

    func beginRun() {
        intervalsMs.removeAll()
        blocksMs.removeAll()
        origin = CACurrentMediaTime()
        last = origin
    }

    @objc private func tick() {
        SwitchTrace.tick()
        let now = CACurrentMediaTime()
        defer { last = now }
        guard last != 0 else { return }
        let interval = (now - last) * 1000
        intervalsMs.append(interval)
        if interval > 20 {
            blocksMs.append([(last - origin) * 1000, interval])
        }
    }
}
