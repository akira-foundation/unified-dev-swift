import Foundation

extension ConversationHandoff {
    final class Measure {
        private struct Key: Hashable {
            var turn: Int
            var detailed: Bool
            var ownerShown: Bool
            var capped: Bool
            var toolsDropped: Int
            var repliesDropped: Int
        }

        private var lengths: [Key: Int] = [:]
        private(set) var renderedTurns = 0

        private static let wrapping = preamble.count + BridgeUntrustedText.opening.count
            + BridgeUntrustedText.closing.count + 3
        private static let separator = 2

        func length(_ context: Context, _ cuts: Cuts) -> Int {
            var total = Self.wrapping
            var sections = 0
            for section in layout(context, cuts) {
                guard let count = length(section, cuts) else { continue }
                total += count
                sections += 1
            }
            return total + max(0, sections - 1) * Self.separator
        }

        private func length(_ section: Section, _ cuts: Cuts) -> Int? {
            guard case .turn(let turn, let detailed, let ownerShown) = section else {
                return render(section, cuts).map { BridgeUntrustedText.escaping($0).count }
            }
            let holdsCuts = detailed && !turn.isComplete
            let key = Key(
                turn: turn.number, detailed: detailed, ownerShown: ownerShown,
                capped: holdsCuts && cuts.capped,
                toolsDropped: holdsCuts ? cuts.toolsDropped : 0,
                repliesDropped: holdsCuts ? cuts.repliesDropped : 0
            )
            if let known = lengths[key] { return known < 0 ? nil : known }
            renderedTurns += 1
            let count = render(section, cuts).map { BridgeUntrustedText.escaping($0).count }
            lengths[key] = count ?? -1
            return count
        }
    }

    static func fitted(_ context: Context, budget: Int, measure: Measure = Measure()) -> String {
        var cuts = Cuts()
        let stages: [(WritableKeyPath<Cuts, Int>, Int)] = [
            (\.completeThrough, context.completeCount),
            (\.cappedLevel, 1),
            (\.toolsDropped, context.unfinished?.lines.count ?? 0),
            (\.repliesDropped, context.unfinished?.replies.count ?? 0),
            (\.ownersDropped, max(0, context.ownerCount - 1)),
            (\.worktreeDropped, 1),
        ]
        for (path, maximum) in stages {
            guard measure.length(context, cuts) > budget else { break }
            cuts[keyPath: path] = fewest(from: cuts[keyPath: path], to: maximum) { value in
                var trial = cuts
                trial[keyPath: path] = value
                return measure.length(context, trial) <= budget
            }
        }
        let whole = document(context, cuts)
        return whole.count <= budget ? whole : newestPart(of: render(context, cuts), budget: budget, chatID: context.chatID)
    }

    static func document(_ context: Context, _ cuts: Cuts) -> String {
        wrap(render(context, cuts))
    }

    private static func wrap(_ body: String) -> String {
        preamble + "\n" + BridgeUntrustedText.opening + "\n" + BridgeUntrustedText.escaping(body)
            + "\n" + BridgeUntrustedText.closing
    }

    private static func newestPart(of body: String, budget: Int, chatID: SessionID) -> String {
        let notice = "Only the newest part of this record fits. The rest is in chat_read on chat \(chatID.rawValue).\n\n"
        let kept = fewest(from: 0, to: body.count) { wrap(notice + body.suffix($0)).count > budget }
        return wrap(notice + body.suffix(max(0, kept - 1)))
    }

    private static func fewest(from start: Int, to maximum: Int, fits: (Int) -> Bool) -> Int {
        var low = start
        var high = max(start, maximum)
        while low < high {
            let middle = (low + high) / 2
            if fits(middle) { high = middle } else { low = middle + 1 }
        }
        return low
    }
}
