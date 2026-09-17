import Foundation

public enum BrowserSnapshot {
    static let maxLabelLength = 40

    public static let agentWidth: Double = 900

    public static func filename(
        for address: String,
        at date: Date = .now,
        avoiding taken: Set<String> = [],
        timeZone: TimeZone = .current
    ) -> String {
        let label = self.label(for: address)
        let stamp = PastedAttachment.timestamp(date, in: timeZone)
        let name = label.isEmpty ? "Page \(stamp).png" : "\(label) \(stamp).png"
        return PastedAttachment.uniqued(name, avoiding: taken)
    }

    public static func label(for address: String) -> String {
        guard let components = URLComponents(string: address), let host = components.host else {
            return ""
        }
        var label = host
        if let port = components.port { label += "-\(port)" }

        let path = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "-")
        if !path.isEmpty { label += "-\(path)" }

        label = String(label.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) || "-._".unicodeScalars.contains(scalar)
                ? Character(scalar)
                : "-"
        })
        while label.hasPrefix("-") || label.hasPrefix(".") { label.removeFirst() }
        while label.hasSuffix("-") || label.hasSuffix(".") { label.removeLast() }

        return String(label.prefix(maxLabelLength))
    }
}
