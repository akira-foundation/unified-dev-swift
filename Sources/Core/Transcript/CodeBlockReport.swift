import Foundation

public enum CodeBlockReport {
    public static func message(command: String, run: CodeBlockRun) -> String? {
        guard case .finished = run else { return nil }
        let shown = command
            .components(separatedBy: "\n")
            .enumerated()
            .map { $0.offset == 0 ? "$ " + $0.element : "> " + $0.element }
            .joined(separator: "\n")
        let body = shown + "\n" + (run.output ?? "(no output)")
        let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: body) + 1))
        return "I ran this command from your reply. \(run.summary). Check that it went as expected.\n\n"
            + fence + "\n" + body + "\n" + fence
    }

    static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}
