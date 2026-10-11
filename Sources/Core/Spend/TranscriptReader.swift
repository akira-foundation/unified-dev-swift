import Foundation

public struct TranscriptReadResult: Sendable {
    public var records: [SpendRecord]
    public var offset: Int
    public var carry: TranscriptCarry
    public var bytesRead: Int
    public var reachedEnd: Bool
    public var abandonedLines: Int

    public init(
        records: [SpendRecord] = [],
        offset: Int = 0,
        carry: TranscriptCarry = TranscriptCarry(),
        bytesRead: Int = 0,
        reachedEnd: Bool = true,
        abandonedLines: Int = 0
    ) {
        self.records = records
        self.offset = offset
        self.carry = carry
        self.bytesRead = bytesRead
        self.reachedEnd = reachedEnd
        self.abandonedLines = abandonedLines
    }
}

public enum TranscriptReader {
    public static let chunkSize = 1 << 20
    public static let defaultBudget = 16 << 20
    public static let lineLimit = 64 << 20

    public static func read(
        _ file: TranscriptFile,
        from start: Int,
        carry: TranscriptCarry,
        budget: Int = defaultBudget
    ) throws -> TranscriptReadResult {
        let handle = try FileHandle(forReadingFrom: file.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(max(0, start)))

        var result = TranscriptReadResult(offset: max(0, start), carry: carry, reachedEnd: true)
        var pending = [UInt8]()
        var pendingStart = result.offset
        var consumed = 0
        var hitEnd = false

        while consumed < budget {
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                hitEnd = true
                break
            }
            consumed += chunk.count
            result.bytesRead += chunk.count
            pending.append(contentsOf: chunk)
            drain(&pending, &pendingStart, file: file, into: &result)
            if pending.count > lineLimit {
                result.abandonedLines += 1
                pendingStart += pending.count
                pending.removeAll(keepingCapacity: false)
                skipToNewline(handle, &pendingStart, &consumed, &result)
            }
        }

        result.offset = pendingStart
        result.reachedEnd = hitEnd
        return result
    }

    private static func drain(
        _ pending: inout [UInt8],
        _ pendingStart: inout Int,
        file: TranscriptFile,
        into result: inout TranscriptReadResult
    ) {
        var carry = result.carry
        var records = result.records
        var cut = 0
        pending.withUnsafeBufferPointer { buffer in
            var lineStart = 0
            for index in 0..<buffer.count where buffer[index] == UInt8(ascii: "\n") {
                if index > lineStart,
                   let record = UsageLine.record(
                       in: buffer,
                       from: lineStart,
                       to: index,
                       provider: file.provider,
                       carry: &carry
                   ) {
                    records.append(record)
                }
                lineStart = index + 1
            }
            cut = lineStart
        }
        guard cut > 0 else { return }
        pending.removeFirst(cut)
        pendingStart += cut
        result.records = records
        result.carry = carry
    }

    private static func skipToNewline(
        _ handle: FileHandle,
        _ pendingStart: inout Int,
        _ consumed: inout Int,
        _ result: inout TranscriptReadResult
    ) {
        while let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
            consumed += chunk.count
            result.bytesRead += chunk.count
            if let newline = chunk.firstIndex(of: UInt8(ascii: "\n")) {
                pendingStart += chunk.distance(from: chunk.startIndex, to: newline) + 1
                return
            }
            pendingStart += chunk.count
        }
    }
}
