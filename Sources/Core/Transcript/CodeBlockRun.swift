import Foundation

public enum CodeBlockRun: Sendable, Equatable {
    case running
    case finished(status: Int32, output: String, duration: Duration)
    case stopped
    case failed(String)

    public enum Mark: Sendable, Equatable {
        case progress
        case succeeded
        case failed
        case stopped
    }

    static let outputLimit = 16_000
    static let linesBeforeScrolling = 12

    public static func finished(_ result: ShellResult, after duration: Duration) -> CodeBlockRun {
        .finished(status: result.status, output: kept(result.stdout), duration: duration)
    }

    public var isRunning: Bool { self == .running }

    public var output: String? {
        guard case let .finished(_, output, _) = self, !output.isEmpty else { return nil }
        return output
    }

    public var succeeded: Bool {
        guard case let .finished(status, _, _) = self else { return false }
        return status == 0
    }

    public var mark: Mark {
        switch self {
        case .running: .progress
        case .finished where succeeded: .succeeded
        case .finished, .failed: .failed
        case .stopped: .stopped
        }
    }

    public var outputScrolls: Bool {
        (output?.count(where: \.isNewline) ?? 0) >= Self.linesBeforeScrolling
    }

    public var summary: String {
        switch self {
        case .running: "Running"
        case let .finished(status, _, duration) where status == 0: "Finished in \(Self.text(duration))"
        case let .finished(status, _, duration): "Exited with status \(status) after \(Self.text(duration))"
        case .stopped: "Stopped"
        case let .failed(reason): "Could not run: \(reason)"
        }
    }

    static func kept(_ output: String) -> String {
        let trimmed = output.trimmingCharacters(in: .newlines)
        guard trimmed.count > outputLimit else { return trimmed }
        let tail = trimmed.suffix(outputLimit)
        let start = tail.firstIndex(where: \.isNewline).map { tail.index(after: $0) } ?? tail.startIndex
        let shown = tail[start...]
        let dropped = trimmed.dropLast(shown.count)
        guard dropped.last?.isNewline == true else { return "(earlier output left out)\n" + shown }
        let omitted = dropped.count(where: \.isNewline)
        return "(\(omitted) earlier \(omitted == 1 ? "line" : "lines") left out)\n" + shown
    }

    static func text(_ duration: Duration) -> String {
        TurnDuration.format(Int(duration / .milliseconds(1)))
    }
}
