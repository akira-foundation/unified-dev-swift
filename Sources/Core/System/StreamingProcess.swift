import Foundation
import Synchronization

public final class StreamingProcess: Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()

    private struct State {
        var stdoutBuffer = Data()
        var stderrBuffer = Data()
        var exitWaiters: [CheckedContinuation<Int32, Never>] = []
        var status: Int32?
        var stdinClosed = false
        var stdinHandleClosed = false
        var stdinWriters = 0
        var started = false
        var stdoutAtEOF = false
        var stderrAtEOF = false
        var lastOutputAt = DispatchTime.now()
        var exitedAt: DispatchTime?
    }

    private let state = Mutex(State())

    private let drainQueue = DispatchQueue(label: "io.akira.unifieddev.StreamingProcess.drain")

    private let linesStream: AsyncThrowingStream<String, Error>
    private let linesContinuation: AsyncThrowingStream<String, Error>.Continuation
    private let errorStream: AsyncStream<String>
    private let errorContinuation: AsyncStream<String>.Continuation

    public let mergeStderr: Bool

    private let executable: String
    private let arguments: [String]
    private let cwd: String?
    private let environment: [String: String]

    private static let eofQuietPeriod = DispatchTimeInterval.milliseconds(200)
    private static let eofHardLimit = DispatchTimeInterval.seconds(5)
    private static let eofPollInterval = DispatchTimeInterval.milliseconds(20)

    public init(
        executable: String,
        arguments: [String],
        cwd: String? = nil,
        environment: [String: String] = Shell.environment(),
        mergeStderr: Bool = true
    ) {
        self.executable = executable
        self.arguments = arguments
        self.cwd = cwd
        self.environment = environment
        self.mergeStderr = mergeStderr

        (linesStream, linesContinuation) = AsyncThrowingStream.makeStream(
            of: String.self, throwing: Error.self, bufferingPolicy: .unbounded
        )
        (errorStream, errorContinuation) = AsyncStream.makeStream(
            of: String.self, bufferingPolicy: .bufferingNewest(4_096)
        )

        linesContinuation.onTermination = { [weak self] reason in
            if case .cancelled = reason { self?.terminate() }
        }

        _ = fcntl(stdinPipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
    }

    public var isRunning: Bool {
        state.withLock { $0.started && $0.status == nil }
    }

    public var processIdentifier: Int32 {
        process.isRunning ? process.processIdentifier : -1
    }

    public var lines: AsyncThrowingStream<String, Error> {
        try? start()
        return linesStream
    }

    public var errorLines: AsyncStream<String> { errorStream }

    public func start() throws {
        let claimed = state.withLock { state -> Bool in
            if state.started { return false }
            state.started = true
            return true
        }
        guard claimed else { return }

        guard let path = Shell.which(executable) else {
            let error = ShellError(command: executable, status: 127, stderr: "\(executable) not found on PATH")
            finish(status: 127, error: error)
            throw error
        }

        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment
        if let cwd { process.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                self.drainStdout(final: true)
                self.markEOF(stdout: true)
            } else {
                self.state.withLock { state in
                    state.stdoutBuffer.append(data)
                    state.lastOutputAt = DispatchTime.now()
                }
                self.drainStdout(final: false)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                self.drainStderr(final: true)
                self.markEOF(stdout: false)
            } else {
                self.state.withLock { state in
                    state.stderrBuffer.append(data)
                    state.lastOutputAt = DispatchTime.now()
                }
                self.drainStderr(final: false)
            }
        }

        process.terminationHandler = { [weak self] process in
            self?.settle(status: process.terminationStatus, deadline: nil)
        }

        do {
            try process.run()
        } catch {
            finish(status: -1, error: error)
            throw error
        }
    }

    public func write(_ text: String) {
        let claimed = state.withLock { state -> Bool in
            guard state.started, state.status == nil, !state.stdinClosed, !state.stdinHandleClosed
            else { return false }
            state.stdinWriters += 1
            return true
        }
        guard claimed else { return }
        defer { releaseWriter() }

        let data = Data(text.utf8)
        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        } catch {
            state.withLock { $0.stdinClosed = true }
        }
    }

    public func writeLine(_ text: String) {
        write(text + "\n")
    }

    private func releaseWriter() {
        let close = state.withLock { state -> Bool in
            state.stdinWriters -= 1
            guard state.stdinClosed, state.stdinWriters == 0, !state.stdinHandleClosed
            else { return false }
            state.stdinHandleClosed = true
            return true
        }
        guard close else { return }
        try? stdinPipe.fileHandleForWriting.close()
    }

    public func closeStdin() {
        let close = state.withLock { state -> Bool in
            state.stdinClosed = true
            guard state.stdinWriters == 0, !state.stdinHandleClosed else { return false }
            state.stdinHandleClosed = true
            return true
        }
        guard close else { return }
        try? stdinPipe.fileHandleForWriting.close()
    }

    public func terminate() {
        signalGroup(SIGTERM)
        closeStdin()
    }

    public func kill() {
        signalGroup(SIGKILL)
    }

    private func signalGroup(_ signal: Int32) {
        guard process.isRunning else { return }
        let pid = process.processIdentifier
        guard pid > 0 else { return }

        let group = getpgid(pid)
        if group > 0, group != getpgrp(), killpg(group, signal) == 0 { return }

        Foundation.kill(pid, signal)
    }

    public var exitStatus: Int32 {
        get async {
            await withCheckedContinuation { continuation in
                register(continuation)
            }
        }
    }

    private func register(_ continuation: CheckedContinuation<Int32, Never>) {
        let ready = state.withLock { state -> Int32? in
            guard let status = state.status else {
                state.exitWaiters.append(continuation)
                return nil
            }
            return status
        }
        if let ready { continuation.resume(returning: ready) }
    }

    private func markEOF(stdout: Bool) {
        state.withLock { state in
            if stdout { state.stdoutAtEOF = true } else { state.stderrAtEOF = true }
        }
    }

    private func settle(status: Int32, deadline: DispatchTime?) {
        let limit = deadline ?? DispatchTime.now() + Self.eofHardLimit
        let now = DispatchTime.now()

        let (sawEOF, since, stdoutLive, stderrLive) = state.withLock { state -> (Bool, DispatchTime, Bool, Bool) in
            let exited = state.exitedAt ?? now
            state.exitedAt = exited
            return (
                state.stdoutAtEOF && state.stderrAtEOF,
                max(state.lastOutputAt, exited),
                !state.stdoutAtEOF,
                !state.stderrAtEOF
            )
        }

        let pending = (stdoutLive && Self.hasPendingBytes(stdoutPipe.fileHandleForReading))
            || (stderrLive && Self.hasPendingBytes(stderrPipe.fileHandleForReading))
        let quiet = now > since + Self.eofQuietPeriod && !pending
        guard sawEOF || quiet || now > limit else {
            DispatchQueue.global().asyncAfter(deadline: now + Self.eofPollInterval) { [weak self] in
                self?.settle(status: status, deadline: limit)
            }
            return
        }

        drainQueue.async { [self] in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            drainStdoutNow(final: true)
            drainStderrNow(final: true)
            finish(status: status, error: nil)
        }
    }

    private static func hasPendingBytes(_ handle: FileHandle) -> Bool {
        var descriptor = pollfd(fd: handle.fileDescriptor, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, 0) > 0 else { return false }
        return descriptor.revents & Int16(POLLIN) != 0
    }

    private func drainStdout(final: Bool) {
        drainQueue.async { [self] in drainStdoutNow(final: final) }
    }

    private func drainStderr(final: Bool) {
        drainQueue.async { [self] in drainStderrNow(final: final) }
    }

    private func drainStdoutNow(final: Bool) {
        let extracted = state.withLock {
            Self.extractLines(from: &$0.stdoutBuffer, flushRemainder: final)
        }
        for line in extracted { linesContinuation.yield(line) }
    }

    private func drainStderrNow(final: Bool) {
        let extracted = state.withLock {
            Self.extractLines(from: &$0.stderrBuffer, flushRemainder: final)
        }
        for line in extracted {
            if mergeStderr {
                linesContinuation.yield(line)
            } else {
                errorContinuation.yield(line)
            }
        }
    }

    private static func extractLines(from buffer: inout Data, flushRemainder: Bool) -> [String] {
        var lines: [String] = []
        while let index = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<index]
            buffer.removeSubrange(buffer.startIndex...index)
            var line = String(decoding: lineData, as: UTF8.self)
            if line.hasSuffix("\r") { line.removeLast() }
            lines.append(line)
        }
        if flushRemainder, !buffer.isEmpty {
            lines.append(String(decoding: buffer, as: UTF8.self))
            buffer.removeAll()
        }
        return lines
    }

    private func finish(status: Int32, error: Error?) {
        let waiters = state.withLock { state -> [CheckedContinuation<Int32, Never>]? in
            guard state.status == nil else { return nil }
            state.status = status
            let waiters = state.exitWaiters
            state.exitWaiters = []
            return waiters
        }
        guard let waiters else { return }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        linesContinuation.finish(throwing: error)
        errorContinuation.finish()
        for waiter in waiters { waiter.resume(returning: status) }
    }
}
