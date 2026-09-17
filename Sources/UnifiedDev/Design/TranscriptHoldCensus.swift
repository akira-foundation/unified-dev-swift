import Core
import Foundation
import QuartzCore

@MainActor
enum TranscriptHoldCensus {
    private(set) static var arrivals = 0
    private(set) static var reveals = 0
    private(set) static var measurements = 0
    private(set) static var estimatedRows = 0
    private(set) static var silencedRows = 0
    private(set) static var silences: [Silence] = []
    private(set) static var widthMismatches = 0
    private(set) static var mismatches: [Mismatch] = []
    private(set) static var correctedRows = 0
    private(set) static var uncorrectedRows = 0
    private(set) static var screenEstimated = 0
    private(set) static var screenWrong = 0
    private(set) static var screensSeen = 0
    private(set) static var screenEstimatedSettled = 0
    private(set) static var screenWrongSettled = 0
    private(set) static var noteCalls = 0
    private(set) static var notedRows = 0
    private(set) static var placeWrites = 0
    private(set) static var entryPasses = 0
    private(set) static var entriesBuilt = 0
    private(set) static var cellsAsked = 0
    private(set) static var cellsBuilt = 0
    private(set) static var cellSeconds = 0.0
    private(set) static var cellWorstMs = 0.0
    private(set) static var heightAsks = 0
    private(set) static var noteSeconds = 0.0
    private(set) static var noteWorstMs = 0.0

    static func arrived() { arrivals += 1 }

    static func revealed() { reveals += 1 }

    static func measured() { measurements += 1 }

    static func released(estimated: Int) { estimatedRows = estimated }

    static func sawScreen(estimated: Int, wrong: Int, settled: Bool = false) {
        screensSeen += 1
        screenEstimated = max(screenEstimated, estimated)
        screenWrong = max(screenWrong, wrong)
        if settled {
            screenEstimatedSettled = estimated
            screenWrongSettled = wrong
        }
    }

    static func placed() { placeWrites += 1 }

    static func askedCell(rebuilt: Bool, seconds: Double) {
        cellsAsked += 1
        guard rebuilt else { return }
        cellsBuilt += 1
        cellSeconds += seconds
        cellWorstMs = max(cellWorstMs, seconds * 1000)
    }

    static func askedHeight() { heightAsks += 1 }

    static func noted(rows: Int, seconds: Double) {
        noteCalls += 1
        notedRows += rows
        noteSeconds += seconds
        noteWorstMs = max(noteWorstMs, seconds * 1000)
    }

    static func clock() -> Double {
        PaneLayoutTiming.isEnabled ? CACurrentMediaTime() : 0
    }

    static func since(_ started: Double) -> Double {
        started > 0 ? CACurrentMediaTime() - started : 0
    }

    static func builtEntries(_ count: Int) {
        entryPasses += 1
        entriesBuilt += count
    }

    static func silenced(_ silence: Silence) {
        silencedRows += 1
        guard silences.count < mostSilences else { return }
        silences.append(silence)
    }

    struct Silence: Sendable {
        var row: Int
        var source: String
        var shape: String
        var columnWidth: Double
        var viewportWidth: Double
        var viewportHeight: Double
    }

    private static let mostSilences = 200

    static func reportedAtAnotherWidth(_ mismatch: Mismatch) {
        widthMismatches += 1
        guard mismatches.count < mostMismatches else { return }
        mismatches.append(mismatch)
    }

    struct Mismatch: Sendable {
        var row: Int
        var shape: String
        var reportedWidth: Double
        var cacheWidth: Double
        var columnWidth: Double
        var cellWidth: Double
        var reportedHeight: Double
        var knownHeight: Double
    }

    private static let mostMismatches = 200

    static func corrected(rows: Int, uncorrected: Int) {
        correctedRows += rows
        uncorrectedRows += uncorrected
    }

    static func reset() {
        arrivals = 0
        reveals = 0
        measurements = 0
        estimatedRows = 0
        correctedRows = 0
        uncorrectedRows = 0
        screenEstimated = 0
        screenWrong = 0
        screensSeen = 0
        screenEstimatedSettled = 0
        screenWrongSettled = 0
        noteCalls = 0
        notedRows = 0
        placeWrites = 0
        cellsAsked = 0
        cellsBuilt = 0
        cellSeconds = 0
        cellWorstMs = 0
        heightAsks = 0
        noteSeconds = 0
        noteWorstMs = 0
        entryPasses = 0
        entriesBuilt = 0
        silencedRows = 0
        silences = []
        widthMismatches = 0
        mismatches = []
    }

    static func summary() -> [String: Double] {
        [
            "arrivals": Double(arrivals),
            "reveals": Double(reveals),
            "measurements": Double(measurements),
            "estimatedRows": Double(estimatedRows),
            "correctedRows": Double(correctedRows),
            "uncorrectedRows": Double(uncorrectedRows),
            "screenEstimated": Double(screenEstimated),
            "screenWrong": Double(screenWrong),
            "screensSeen": Double(screensSeen),
            "screenEstimatedSettled": Double(screenEstimatedSettled),
            "screenWrongSettled": Double(screenWrongSettled),
            "noteCalls": Double(noteCalls),
            "notedRows": Double(notedRows),
            "placeWrites": Double(placeWrites),
            "cellsAsked": Double(cellsAsked),
            "cellsBuilt": Double(cellsBuilt),
            "cellSeconds": cellSeconds,
            "cellWorstMs": cellWorstMs,
            "heightAsks": Double(heightAsks),
            "noteSeconds": noteSeconds,
            "noteWorstMs": noteWorstMs,
            "entryPasses": Double(entryPasses),
            "entriesBuilt": Double(entriesBuilt),
            "silencedRows": Double(silencedRows),
            "widthMismatches": Double(widthMismatches),
        ]
    }
}
