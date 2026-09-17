import SwiftUI

enum MatchedRuns {
    static func text(_ string: String, highlights: [Int], loud: Color, quiet: Color) -> Text {
        var runs = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        append(string, highlights: highlights, loud: loud, quiet: quiet, to: &runs)
        return Text(LocalizedStringKey(stringInterpolation: runs))
    }

    static func append(
        _ string: String,
        highlights: [Int],
        loud: Color,
        quiet: Color,
        to runs: inout LocalizedStringKey.StringInterpolation
    ) {
        guard !highlights.isEmpty else {
            runs.appendInterpolation(Text(string).foregroundStyle(loud))
            return
        }

        let characters = Array(string)
        let hits = Set(highlights)
        var index = 0
        while index < characters.count {
            let isHit = hits.contains(index)
            var end = index
            while end < characters.count, hits.contains(end) == isHit { end += 1 }
            let run = Text(String(characters[index..<end]))
            runs.appendInterpolation(
                isHit ? run.fontWeight(.bold).foregroundStyle(loud) : run.foregroundStyle(quiet)
            )
            index = end
        }
    }
}
