import AppKit
import QuartzCore
import SwiftUI

@MainActor
@Observable
final class TranscriptLiveEndScroller {
    @ObservationIgnored weak var scrollView: NSScrollView?

    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var start: CFTimeInterval = 0
    @ObservationIgnored private var from: CGFloat = 0
    @ObservationIgnored private var to: CGFloat = 0
    @ObservationIgnored private var duration: Double = 0
    @ObservationIgnored private var arrival: (@MainActor () -> Void)?

    @discardableResult
    func glide(seconds: Double, completion: @escaping @MainActor () -> Void) -> Bool {
        guard let scrollView, let document = scrollView.documentView else { return false }

        let clip = scrollView.contentView
        let reach = scrollView.endOffset
        guard reach > 0 else { return false }

        let end = document.isFlipped ? reach : 0
        guard abs(clip.bounds.origin.y - end) > 0.5, seconds > 0 else { return false }

        stop()
        from = clip.bounds.origin.y
        to = end
        duration = seconds
        start = CACurrentMediaTime()
        arrival = completion

        let created = clip.displayLink(target: self, selector: #selector(step))
        created.add(to: .main, forMode: .common)
        link = created
        return true
    }

    func stop() {
        link?.invalidate()
        link = nil
        arrival = nil
    }

    @objc private func step(_ sender: CADisplayLink) {
        MainActor.assumeIsolated {
            guard let scrollView else { return stop() }
            let clip = scrollView.contentView
            let elapsed = CACurrentMediaTime() - start
            let ratio = duration > 0 ? min(1, max(0, elapsed / duration)) : 1
            let eased = 1 - pow(1 - ratio, 3)
            clip.setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: from + (to - from) * eased))
            scrollView.reflectScrolledClipView(clip)

            guard ratio >= 1 else { return }
            let landed = arrival
            stop()
            landed?()
        }
    }
}
