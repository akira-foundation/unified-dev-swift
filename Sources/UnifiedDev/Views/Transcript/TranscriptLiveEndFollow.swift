import AppKit
import Core
import QuartzCore
import SwiftUI

@MainActor
final class TranscriptLiveEndFollower {
    weak var scrollView: NSScrollView? {
        didSet {
            guard scrollView !== oldValue else { return }
            lastHeight = 0
            forgetTheView()
            refresh()
        }
    }

    var isStreaming = false { didSet { refresh() } }

    var isFrontmost = true { didSet { refresh() } }

    var isPaused = false { didSet { refresh() } }

    private(set) var isSeekingLiveEnd = false

    func seekLiveEnd(_ seeking: Bool) {
        isSeekingLiveEnd = seeking
        if seeking {
            dropLink()
        } else {
            refresh()
        }
    }

    var travels = true { didSet { refresh() } }

    var onRest: (@MainActor () -> Void)?

    var onStart: (@MainActor () -> Bool)?

    var onStop: (@MainActor () -> Void)?

    private static let grace: Double = 0.5

    private var link: CADisplayLink?
    private var deadline: CFTimeInterval = 0
    private var lastFrame: CFTimeInterval = 0
    private var lastHeight: CGFloat = 0

    private var lastPut: CGFloat?
    private var ownsGap = false

    var isFollowing: Bool { link != nil && ownsGap }

    func nudge() {
        deadline = CACurrentMediaTime() + Self.grace
        refresh()
    }

    func stop() {
        deadline = 0
        forget()
        forgetTheView()
        dropLink()
        isSeekingLiveEnd = false
    }

    func forget() {
        lastHeight = 0
    }

    private func forgetTheView() {
        lastPut = nil
        ownsGap = false
    }

    private var wants: Bool {
        guard travels, isFrontmost, !isPaused, !isSeekingLiveEnd, scrollView != nil else { return false }
        return isStreaming || CACurrentMediaTime() < deadline
    }

    private func refresh() {
        if wants { startLink() } else { endLink() }
    }

    private func startLink() {
        guard link == nil, let scrollView else { return }
        lastFrame = 0
        forgetTheView()
        ownsGap = onStart?() ?? false
        if ownsGap { lastPut = scrollView.contentView.bounds.origin.y }
        let created = scrollView.contentView.displayLink(target: self, selector: #selector(step))
        created.add(to: .main, forMode: .common)
        link = created
    }

    private func endLink() {
        guard dropLink() else { return }
        if isAtEnd {
            onRest?()
            return
        }
        guard !isPaused, ownsGap else { return }
        onRest?()
    }

    @discardableResult
    private func dropLink() -> Bool {
        guard link != nil else { return false }
        link?.invalidate()
        link = nil
        onStop?()
        return true
    }

    private var isAtEnd: Bool {
        guard let scrollView else { return false }
        return scrollView.distanceFromEnd <= TranscriptFollow.arrived
    }

    @objc private func step(_ sender: CADisplayLink) {
        MainActor.assumeIsolated {
            guard wants, let scrollView, let document = scrollView.documentView else { return endLink() }
            guard document.isFlipped else { return endLink() }

            let clip = scrollView.contentView
            guard TranscriptAnchor.canPlace(viewportHeight: Double(clip.bounds.height)) else {
                return
            }
            let now = CACurrentMediaTime()
            let frame = lastFrame > 0 ? now - lastFrame : 0
            lastFrame = now

            let height = document.frame.height
            let end = scrollView.endOffset
            var offset = clip.bounds.origin.y

            if let lastPut, offset < lastPut - CGFloat(TranscriptFollow.arrived) { ownsGap = false }

            if lastHeight > 0, height > lastHeight {
                offset = TranscriptFollow.start(
                    offset: offset, end: end, grew: height - lastHeight, ownsGap: ownsGap
                )
            }
            lastHeight = height

            switch TranscriptFollow.step(offset: offset, end: end, frame: frame, ownsGap: ownsGap) {
            case .rest:
                if offset != clip.bounds.origin.y { put(offset, in: clip, of: scrollView) }
            case .settle(let next):
                put(next, in: clip, of: scrollView)
            }

            if !isStreaming, now >= deadline { endLink() }
        }
    }

    private func put(_ y: CGFloat, in clip: NSClipView, of scrollView: NSScrollView) {
        clip.setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: y))
        scrollView.reflectScrolledClipView(clip)
        lastPut = clip.bounds.origin.y
        ownsGap = true
    }
}
