import Foundation

public struct SetupDiagnosis: Sendable, Hashable {
    public let summary: String

    public let scriptLine: Int?

    public let advice: String

    public let status: Int?

    public init(summary: String, scriptLine: Int? = nil, advice: String = "", status: Int? = nil) {
        self.summary = summary
        self.scriptLine = scriptLine
        self.advice = advice
        self.status = status
    }

    public var title: String {
        status.map { "Setup failed (\($0))" } ?? "Setup failed"
    }

    public var sentence: String {
        [advice, scriptLine.map { "The shell put it at line \($0) of the script." } ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func read(log: String, status: Int? = nil) -> SetupDiagnosis {
        let summary = failureLine(in: log)
        return SetupDiagnosis(
            summary: summary,
            scriptLine: scriptLine(in: summary),
            advice: advice(for: summary),
            status: status
        )
    }

    private static let reach = 20

    static func split(_ log: String) -> [String] {
        log.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    static func failureLine(in log: String) -> String {
        let lines = split(log)

        var end = lines.count
        while end > 0, lines[end - 1].trimmingCharacters(in: .whitespaces).isEmpty { end -= 1 }
        guard end > 0 else { return "" }

        var seen = 0
        var index = end - 1
        while index >= 0, seen < reach {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                seen += 1
                if isDiagnostic(line) { return line.trimmingCharacters(in: .whitespaces) }
            }
            index -= 1
        }

        index = end - 1
        while index >= 0 {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespaces).isEmpty, !isContinuation(line) {
                return line.trimmingCharacters(in: .whitespaces)
            }
            index -= 1
        }

        return lines[end - 1].trimmingCharacters(in: .whitespaces)
    }

    static func isContinuation(_ line: String) -> Bool {
        guard let first = line.first, first == " " || first == "\t" else { return false }
        return !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func isDiagnostic(_ line: String) -> Bool {
        let value = line.trimmingCharacters(in: .whitespaces).lowercased()
        for opening in ["error:", "fatal:", "fatal error:"] where value.hasPrefix(opening) {
            return true
        }
        for marker in [": error:", ": fatal:", ": fatal error:"] where value.contains(marker) {
            return true
        }
        return false
    }

    static func advice(for summary: String) -> String {
        let value = summary.lowercased()
        if value.contains("connection refused") { return refusedAdvice(summary) }
        if value.contains("command not found") { return notFoundAdvice(summary) }
        return ""
    }

    private static let wellKnown: [Int: String] = [
        5432: "Postgres",
        3306: "MySQL",
        6379: "Redis",
        27_017: "MongoDB",
        9_200: "Elasticsearch",
    ]

    private static func refusedAdvice(_ summary: String) -> String {
        let port = number(after: "port ", in: summary)
        let host = host(in: summary)

        let place: String
        switch (host, port) {
        case let (host?, port?): place = "on \(host):\(port)"
        case let (nil, port?): place = "on port \(port)"
        case let (host?, nil): place = "on \(host)"
        default: place = "where the script tried to connect"
        }

        let named = port.flatMap { wellKnown[$0] }.map { ", which is where \($0) usually is" } ?? ""
        return "Nothing was listening \(place)\(named). Start it and run setup again."
    }

    private static func notFoundAdvice(_ summary: String) -> String {
        var name = ""
        if let marker = summary.range(of: "command not found: ") {
            name = summary[marker.upperBound...].trimmingCharacters(in: .whitespaces)
        } else if let marker = summary.range(of: ": command not found") {
            name = summary[..<marker.lowerBound]
                .split(separator: ":").last
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        }

        guard !name.isEmpty else {
            return "Something the script called is not on the PATH it ran with."
        }
        return "\(name) is not on the PATH the setup script ran with."
    }

    static func scriptLine(in summary: String) -> Int? {
        guard let marker = summary.range(of: ": line ") else { return nil }
        let rest = summary[marker.upperBound...]
        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, rest.dropFirst(digits.count).first == ":" else { return nil }
        return Int(digits)
    }

    private static func number(after marker: String, in text: String) -> Int? {
        guard let range = text.range(of: marker) else { return nil }
        let digits = text[range.upperBound...].prefix { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }

    private static func host(in text: String) -> String? {
        if let opening = text.range(of: "at \""),
           let closing = text[opening.upperBound...].firstIndex(of: "\"") {
            let value = String(text[opening.upperBound..<closing])
            return value.isEmpty ? nil : value
        }
        if let marker = text.range(of: " port ") {
            let word = text[..<marker.lowerBound].split(separator: " ").last.map(String.init)
            return word?.isEmpty == false ? word : nil
        }
        return nil
    }
}

public struct SetupLogLine: Sendable, Hashable, Identifiable {
    public let id: Int
    public let text: String
    public let isFailure: Bool

    public init(id: Int, text: String, isFailure: Bool) {
        self.id = id
        self.text = text
        self.isFailure = isFailure
    }

    public static func lines(of text: String, failing summary: String) -> [SetupLogLine] {
        var result: [SetupLogLine] = []
        var carrying = false

        for (index, value) in SetupDiagnosis.split(text).enumerated() {
            let trimmed = value.trimmingCharacters(in: .whitespaces)

            if !summary.isEmpty, trimmed == summary {
                carrying = true
            } else if carrying, !SetupDiagnosis.isContinuation(value) {
                carrying = false
            }

            result.append(SetupLogLine(id: index, text: value, isFailure: carrying))
        }
        return result
    }
}
