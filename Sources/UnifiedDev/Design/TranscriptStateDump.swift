import AppKit
import Core
import Foundation

@MainActor
enum TranscriptStateDump {
    struct Pane {
        var scroll: NSScrollView
        var hold: TranscriptHoldView
        var table: NSTableView?
        var coordinator: TranscriptTable.Coordinator?
    }

    static let liveBand = 60

    static let mostTrips = 3

    private static var trips = 0
    private static var signalSource: DispatchSourceSignal?

    static func tripIfBlank(_ pane: Pane) {
        guard trips < mostTrips else { return }
        guard let table = pane.table, table.numberOfRows > 0 else { return }
        guard !pane.hold.isHolding else { return }
        let clip = pane.scroll.contentView
        guard clip.bounds.height > 1 else { return }
        guard table.rows(in: clip.documentVisibleRect).length == 0 else { return }
        trips += 1
        write(pane, reason: "blank", band: liveBand)
    }

    static func listen() {
        guard signalSource == nil else { return }
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                guard let pane = findInAnyWindow() else { return }
                write(pane, reason: "signal", band: liveBand)
            }
        }
        source.resume()
        signalSource = source
    }

    static let latestPath = NSTemporaryDirectory() + "unifieddev-transcript-state.json"

    @discardableResult
    static func write(_ pane: Pane, reason: String, band: Int) -> String? {
        var report = state(of: pane, band: band)
        report["reason"] = .string(reason)
        report["takenAt"] = .string(ISO8601DateFormatter().string(from: .now))
        report["pid"] = .integer(Int(ProcessInfo.processInfo.processIdentifier))
        report["version"] = .string(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        )
        report["build"] = .string(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")
        report["trips"] = .integer(trips)

        guard let data = try? JSONEncoder.sorted.encode(JSONValue.object(report)) else { return nil }
        try? data.write(to: URL(fileURLWithPath: latestPath))
        let stamped = NSTemporaryDirectory()
            + "unifieddev-transcript-state-\(Int(Date.now.timeIntervalSince1970)).json"
        try? data.write(to: URL(fileURLWithPath: stamped))
        return stamped
    }

    static func state(of pane: Pane, band: Int) -> [String: JSONValue] {
        let clip = pane.scroll.contentView
        let offset = Double(clip.bounds.origin.y)
        let end = Double(pane.scroll.endOffset)
        let range = pane.table.map { $0.rows(in: clip.documentVisibleRect) }
        let count = pane.table?.numberOfRows ?? -1
        let visible = range?.length ?? -1
        let facts = rowFacts(pane, band: band)
        let displacements = facts.compactMap { fact in
            fact.drawnTop.map { abs($0 - fact.top) }
        }
        let lost = facts.filter { $0.known == 0 && !$0.drawsNothing && !$0.redrawsItself }
        let guesses = facts.filter { $0.known == nil }.map(\.assumed)
        let measured = facts.compactMap(\.known)

        var out: [String: JSONValue] = [
            "offset": .number(offset),
            "endOffset": .number(end),
            "overshoot": .number(offset - end),
            "contentHeight": .number(Double(pane.scroll.documentView?.frame.height ?? 0)),
            "viewportHeight": .number(Double(clip.bounds.height)),
            "viewportWidth": .number(Double(clip.bounds.width)),
            "scrollAlpha": .number(Double(pane.scroll.alphaValue)),
            "scrollFrame": rect(pane.scroll.frame),
            "holdBounds": rect(pane.hold.bounds),
            "held": .bool(pane.hold.isHolding),
            "cacheWidth": .number(pane.coordinator?.heightCacheWidth ?? 0),
            "cacheIsReady": .bool(pane.coordinator?.heightCacheIsReady ?? false),
            "cached": .integer(pane.coordinator?.heightCacheCount ?? -1),
            "widthMismatches": .integer(TranscriptHoldCensus.widthMismatches),
            "silenced": .integer(TranscriptHoldCensus.silencedRows),
            "cellsBuilt": .integer(TranscriptHoldCensus.cellsBuilt),
            "screenEstimated": .integer(TranscriptHoldCensus.screenEstimated),
            "screenEstimatedSettled": .integer(TranscriptHoldCensus.screenEstimatedSettled),
            "screensSeen": .integer(TranscriptHoldCensus.screensSeen),
            "mismatches": .array(TranscriptHoldCensus.mismatches.map { json(of: $0) }),
            "silences": .array(TranscriptHoldCensus.silences.map { json(of: $0) }),
            "numberOfRows": .integer(count),
            "visibleRows": .integer(visible),
            "misplacedCells": .integer(displacements.filter { $0 > 0.5 }.count),
            "largestCellDisplacement": .number(displacements.max() ?? 0),
            "firstVisibleRow": .integer(range.map { $0.length > 0 ? $0.location : -1 } ?? -1),
            "rowViews": .integer(pane.table?.subviews.count ?? -1),
            "hostedRows": .integer(hostingViewCount(in: pane.table)),
            "isBlank": .bool(count > 0 && visible == 0),
            "rowsAboveBand": .integer(facts.first?.row ?? 0),
            "pointsAboveBand": .number(facts.first?.top ?? 0),
            "pointsPerRowAboveBand": .number(
                (facts.first?.row ?? 0) > 0
                    ? (facts.first?.top ?? 0) / Double(facts.first?.row ?? 1)
                    : 0
            ),
            "largestGuess": .number(guesses.max() ?? 0),
            "measuredPointsPerRow": .number(
                measured.isEmpty ? 0 : measured.reduce(0, +) / Double(measured.count)
            ),
            "measuredRows": .integer(measured.count),
            "lostRows": .integer(lost.count),
            "bandRows": .integer(facts.count),
            "guessedRows": .integer(facts.filter { $0.known == nil && !$0.drawsNothing }.count),
            "cellsHeld": .integer(facts.filter(\.hasCell).count),
            "rows": .array(facts.map { json(of: $0) }),
        ]
        out["lost"] = .array(lost.prefix(40).map { json(of: $0) })
        return out
    }

    private static func rowFacts(
        _ pane: Pane, band: Int
    ) -> [TranscriptTable.Coordinator.RowFact] {
        guard let coordinator = pane.coordinator else { return [] }
        let visible = coordinator.visibleRowRange
        let count = pane.table?.numberOfRows ?? 0
        let middle: Int
        if visible.isEmpty {
            let under = pane.table?.row(
                at: NSPoint(x: 0, y: pane.scroll.contentView.bounds.origin.y)
            ) ?? -1
            middle = under >= 0 ? under : max(0, count - band)
        } else {
            middle = visible.lowerBound
        }
        let lower = max(0, middle - band)
        let upper = min(count, max(visible.upperBound, middle) + band)
        guard lower < upper else { return [] }
        return coordinator.rowFacts(for: lower..<upper)
    }

    static func findInAnyWindow() -> Pane? {
        for window in NSApp.windows {
            guard let content = window.contentView, let pane = find(in: content) else { continue }
            return pane
        }
        return nil
    }

    static func find(in root: NSView) -> Pane? {
        guard let hold = holdView(in: root) else { return nil }
        return Pane(
            scroll: hold.scroll,
            hold: hold,
            table: hold.scroll.documentView as? NSTableView,
            coordinator: hold.delegate as? TranscriptTable.Coordinator
        )
    }

    static func holdView(in root: NSView) -> TranscriptHoldView? {
        if let found = root as? TranscriptHoldView { return found }
        for subview in root.subviews {
            if let found = holdView(in: subview) { return found }
        }
        return nil
    }

    static func json(of fact: TranscriptTable.Coordinator.RowFact) -> JSONValue {
        .object([
            "row": .integer(fact.row),
            "entry": .string(fact.name),
            "shape": .string(fact.shape),
            "drawsNothing": .bool(fact.drawsNothing),
            "known": fact.known.map { JSONValue.number($0) } ?? .null,
            "assumed": .number(fact.assumed),
            "measuredNothing": .bool(fact.measuredNothing),
            "needsMeasuring": .bool(fact.needsMeasuring),
            "told": .number(fact.told),
            "top": .number(fact.top),
            "drawnTop": fact.drawnTop.map(JSONValue.number) ?? .null,
            "drawnHeight": fact.drawnHeight.map(JSONValue.number) ?? .null,
            "redrawsItself": .bool(fact.redrawsItself),
            "hasCell": .bool(fact.hasCell),
        ])
    }

    static func json(of mismatch: TranscriptHoldCensus.Mismatch) -> JSONValue {
        .object([
            "row": .integer(mismatch.row),
            "shape": .string(mismatch.shape),
            "reportedWidth": .number(mismatch.reportedWidth),
            "cacheWidth": .number(mismatch.cacheWidth),
            "columnWidth": .number(mismatch.columnWidth),
            "cellWidth": .number(mismatch.cellWidth),
            "reportedHeight": .number(mismatch.reportedHeight),
            "knownHeight": .number(mismatch.knownHeight),
        ])
    }

    static func json(of silence: TranscriptHoldCensus.Silence) -> JSONValue {
        .object([
            "row": .integer(silence.row),
            "source": .string(silence.source),
            "shape": .string(silence.shape),
            "columnWidth": .number(silence.columnWidth),
            "viewportWidth": .number(silence.viewportWidth),
            "viewportHeight": .number(silence.viewportHeight),
        ])
    }

    static func rect(_ rect: CGRect) -> JSONValue {
        .object([
            "x": .number(Double(rect.origin.x)), "y": .number(Double(rect.origin.y)),
            "w": .number(Double(rect.width)), "h": .number(Double(rect.height)),
        ])
    }

    static func hostingViewCount(in table: NSTableView?) -> Int {
        guard let table else { return -1 }
        var found = 0
        func walk(_ view: NSView) {
            if String(describing: type(of: view)).hasPrefix("NSHostingView") { found += 1 }
            for subview in view.subviews { walk(subview) }
        }
        walk(table)
        return found
    }
}

private extension JSONEncoder {
    static var sorted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }
}
