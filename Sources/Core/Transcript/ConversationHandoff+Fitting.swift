import Foundation

extension ConversationHandoff {
    static func fitted(_ context: Context, budget: Int) -> String {
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
            guard document(context, cuts).count > budget else { break }
            cuts[keyPath: path] = fewest(from: cuts[keyPath: path], to: maximum) { value in
                var trial = cuts
                trial[keyPath: path] = value
                return document(context, trial).count <= budget
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
