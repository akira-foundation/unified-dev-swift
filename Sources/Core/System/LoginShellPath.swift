import Foundation

public enum LoginShellPath {
    static func directories(inEnvironmentDump data: Data) -> [String] {
        for (index, record) in data.split(separator: 0, omittingEmptySubsequences: false).enumerated() {
            let text = String(decoding: record, as: UTF8.self)
            let candidate = index == 0 ? (text.components(separatedBy: "\n").last ?? text) : text
            guard candidate.hasPrefix("PATH=") else { continue }
            return unique(String(candidate.dropFirst("PATH=".count)).components(separatedBy: ":"))
                .filter { $0.hasPrefix("/") }
        }
        return []
    }

    static func merge(discovered: [String], inherited: [String], guessed: [String]) -> [String] {
        unique(discovered + inherited + guessed).filter { !$0.isEmpty }
    }

    private static func unique(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        return entries.filter { seen.insert($0).inserted }
    }
}
