import Foundation

public struct TranscriptRowHeights: Equatable, Sendable {
    public struct Measure: Equatable, Sendable {
        public var width: Double
        public var scale: Double
        public var leading: Double

        public init(width: Double, scale: Double, leading: Double) {
            self.width = width
            self.scale = scale
            self.leading = leading
        }

        func matches(_ other: Measure) -> Bool {
            TranscriptRowHeights.isSameWidth(width, other.width)
                && scale == other.scale
                && leading == other.leading
        }
    }

    public static func isSameWidth(_ one: Double, _ other: Double) -> Bool {
        abs(one - other) <= 0.5
    }

    public static func isEvidence(measuredAt width: Double, forCacheAt cacheWidth: Double?) -> Bool {
        guard let cacheWidth else { return false }
        return isSameWidth(cacheWidth, width)
    }

    public static let mostRows = 20_000

    public static let assumedRowHeight: Double = 64

    public static let mostEstimated: Double = 450

    public static let settleAfter = 24

    public static let resettleDrift = 0.25

    public static let settleShapeAfter = 3

    public static func isSameHeight(_ one: Double, _ other: Double) -> Bool {
        abs(one - other) <= 0.5
    }

    public static let narrowest: Double = 1

    public private(set) var measure: Measure?
    public private(set) var conversation: SessionID?
    private var heights: [TranscriptContentKey: Double] = [:]
    private var stale: Set<TranscriptContentKey> = []
    private var sampled: [TranscriptContentKey: TranscriptRowShape] = [:]
    private var overall = Running()
    private var shapes: [TranscriptRowShape: Running] = [:]

    private struct Running: Equatable, Sendable {
        var inked = 0
        var counts: [Int: Int] = [:]
        var settled: Double?
        var settledFrom = 0

        var estimate: Double? {
            if let settled { return settled }
            return middle
        }

        var middle: Double? {
            guard inked > 0 else { return nil }
            let wanted = (inked - 1) / 2
            var seen = 0
            for height in counts.keys.sorted() {
                seen += counts[height] ?? 0
                if seen > wanted { return Double(height) }
            }
            return nil
        }

        mutating func absorb(_ height: Double, replacing previous: Double, settlingAfter: Int) {
            remove(previous)
            add(height)
            settleIfItIsTime(settlingAfter: settlingAfter)
        }

        mutating func release(_ height: Double) {
            remove(height)
        }

        private mutating func add(_ height: Double) {
            guard height > 0 else { return }
            counts[Int(height), default: 0] += 1
            inked += 1
        }

        private mutating func remove(_ height: Double) {
            guard height > 0 else { return }
            let key = Int(height)
            guard let count = counts[key] else { return }
            if count <= 1 { counts[key] = nil } else { counts[key] = count - 1 }
            inked -= 1
        }

        private mutating func settleIfItIsTime(settlingAfter: Int) {
            guard inked >= settlingAfter else { return }
            if settled != nil, inked < settledFrom * 2 { return }
            guard let running = middle else { return }
            guard let settled else { return take(running) }
            guard abs(running - settled) > settled * TranscriptRowHeights.resettleDrift else {
                return
            }
            take(running)
        }

        private mutating func take(_ estimate: Double) {
            settled = estimate
            settledFrom = inked
        }
    }

    public init() {}

    public var isReady: Bool { measure != nil }

    public var count: Int { heights.count }

    @discardableResult
    public mutating func reset(width: Double, scale: Double, leading: Double) -> Bool {
        guard width > Self.narrowest else { return false }
        let wanted = Measure(width: width, scale: scale, leading: leading)
        if let measure, measure.matches(wanted) { return false }
        measure = wanted
        heights.removeAll()
        stale.removeAll()
        sampled.removeAll()
        overall = Running()
        shapes.removeAll()
        return true
    }

    @discardableResult
    public mutating func showing(_ conversation: SessionID) -> Bool {
        guard self.conversation != conversation else { return false }
        self.conversation = conversation
        sampled.removeAll()
        overall = Running()
        shapes.removeAll()
        return true
    }

    @discardableResult
    public mutating func rewidth(to width: Double) -> Bool {
        guard let current = measure, width > Self.narrowest else { return false }
        guard !Self.isSameWidth(current.width, width) else { return false }
        measure = Measure(width: width, scale: current.scale, leading: current.leading)
        stale = Set(heights.keys)
        return true
    }

    public func isStale(_ contentKey: TranscriptContentKey) -> Bool { stale.contains(contentKey) }

    public var staleCount: Int { stale.count }

    public func needsMeasuring(_ contentKey: TranscriptContentKey, redrawsItself: Bool) -> Bool {
        redrawsItself || heights[contentKey] == nil || stale.contains(contentKey)
    }

    public static func needsRepair(guessed: Int, wrong: Int) -> Bool {
        guessed > 0 || wrong > 0
    }

    public func height(for contentKey: TranscriptContentKey) -> Double? {
        heights[contentKey]
    }

    public func measuredNothing(_ contentKey: TranscriptContentKey) -> Bool {
        heights[contentKey] == 0 && !stale.contains(contentKey)
    }

    public var estimate: Double {
        min(Self.mostEstimated, overall.estimate ?? Self.assumedRowHeight)
    }

    public func estimate(for shape: TranscriptRowShape) -> Double {
        guard shape != .other, let running = shapes[shape],
              running.inked >= Self.settleShapeAfter, let answer = running.estimate
        else { return estimate }
        return min(Self.mostEstimated, answer)
    }

    public func assumed(
        for contentKey: TranscriptContentKey,
        shape: TranscriptRowShape = .other,
        drawsNothing: Bool = false
    ) -> Double {
        if let known = heights[contentKey] { return known }
        return drawsNothing ? 0 : estimate(for: shape)
    }

    @discardableResult
    public mutating func note(
        _ height: Double,
        for contentKey: TranscriptContentKey,
        shape: TranscriptRowShape = .other,
        measuredAt width: Double
    ) -> Bool {
        guard Self.isEvidence(measuredAt: width, forCacheAt: measure?.width) else { return false }
        stale.remove(contentKey)
        let rounded = Self.rounded(height)
        let known = heights[contentKey]
        if heights.count >= Self.mostRows, known == nil { forget() }
        sample(rounded, for: contentKey, shape: shape)
        guard !Self.isSameHeight(known ?? -1, rounded) else { return false }
        heights[contentKey] = rounded
        return true
    }

    private mutating func sample(
        _ height: Double, for contentKey: TranscriptContentKey, shape: TranscriptRowShape
    ) {
        let before = sampled.updateValue(shape, forKey: contentKey)
        let previous = before == nil ? 0 : (heights[contentKey] ?? 0)
        if let before, before != shape { shapes[before, default: Running()].release(previous) }
        overall.absorb(height, replacing: previous, settlingAfter: Self.settleAfter)
        guard shape != .other else { return }
        shapes[shape, default: Running()].absorb(
            height,
            replacing: before == shape ? previous : 0,
            settlingAfter: Self.settleShapeAfter
        )
    }

    public static func rounded(_ height: Double) -> Double {
        max(0, height.rounded(.up))
    }

    public mutating func forget() {
        heights.removeAll()
        stale.removeAll()
        sampled.removeAll()
        overall = Running()
        shapes.removeAll()
    }
}
