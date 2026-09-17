import Core

enum DiffRow: Identifiable {
    case header(hunk: Int, text: String)
    case runExpander(runID: Int, hidden: Int)
    case gapExpander(gapID: Int, hidden: Int)
    case line(DiffLine)
    case pair(SideBySideRow)
    case lineRun([DiffLine])
    case pairRun([SideBySideRow])
    case commentBand(ReviewPlacement)
    case commentEditor(ReviewSpot)
    case lineEditor(DiffEditRegion)

    var sourceLines: [DiffLine] {
        switch self {
        case let .line(line): [line]
        case let .lineRun(lines): lines
        case let .pair(row): [row.left, row.right].compactMap { $0 }
        case let .pairRun(rows): rows.flatMap { [$0.left, $0.right].compactMap { $0 } }
        default: []
        }
    }

    var id: String {
        switch self {
        case let .header(hunk, _): "header-\(hunk)"
        case let .runExpander(runID, _): "run-\(runID)"
        case let .gapExpander(gapID, _): "gap-\(gapID)"
        case let .line(line): "line-\(line.index)"
        case let .pair(row): "pair-\(row.left?.index ?? row.index)-\(row.right?.index ?? .min)"
        case let .lineRun(lines): "linerun-\(lines.first?.index ?? .min)"
        case let .pairRun(rows):
            "pairrun-\(rows.first?.left?.index ?? rows.first?.index ?? .min)"
                + "-\(rows.first?.right?.index ?? .min)"
        case let .commentBand(placement): "band-\(placement.id)"
        case .commentEditor: "editor"
        case .lineEditor: "line-editor"
        }
    }

    var codeLineCount: Int? {
        switch self {
        case let .lineRun(lines): lines.count
        case let .pairRun(pairs): pairs.count
        case .line, .pair: 1
        default: nil
        }
    }

    var isRunnable: Bool {
        switch self {
        case let .line(line):
            return line.kind != .noNewline
        case let .pair(row):
            return row.left?.kind != .noNewline && row.right?.kind != .noNewline
        default:
            return false
        }
    }

    static func grouped(_ rows: [DiffRow], stoppingAt line: Int? = nil) -> [DiffRow] {
        var result: [DiffRow] = []
        result.reserveCapacity(rows.count)

        for chunk in DiffRunGrouping.chunks(count: rows.count, isLine: { rows[$0].isRunnable && !rows[$0].sourceLines.contains { $0.newNumber == line && line != nil } }) {
            switch chunk {
            case let .single(index):
                result.append(rows[index])
            case let .run(range):
                let slice = Array(rows[range])
                if let lines = slice.asLines {
                    result.append(.lineRun(lines))
                } else if let pairs = slice.asPairs {
                    result.append(.pairRun(pairs))
                } else {
                    result.append(contentsOf: slice)
                }
            }
        }

        return result
    }
}

private extension [DiffRow] {
    var asLines: [DiffLine]? {
        var result: [DiffLine] = []
        for row in self {
            guard case let .line(line) = row else { return nil }
            result.append(line)
        }
        return result
    }

    var asPairs: [SideBySideRow]? {
        var result: [SideBySideRow] = []
        for row in self {
            guard case let .pair(pair) = row else { return nil }
            result.append(pair)
        }
        return result
    }
}
