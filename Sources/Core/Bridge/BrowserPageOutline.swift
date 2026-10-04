import Foundation

public enum BrowserPageOutline {
    public static let elementLimit = 400

    public static let nameLimit = 120

    public static let depthLimit = 4

    public static func render(_ elements: [BrowserPageElement], from address: String) -> String {
        guard !elements.isEmpty else {
            return "The page at \(address) answered, and there is nothing on it an agent can "
                + "point at: no buttons, links, fields or boxes. Read it with browser_text if "
                + "what it says is the question."
        }
        let shown = elements.prefix(elementLimit)
        let body = shown.enumerated()
            .map { line($0.element, at: $0.offset + 1) }
            .joined(separator: "\n")
        let fenced = BridgeUntrustedText.wrap(body, from: address)
        guard elements.count > elementLimit else { return fenced }
        return fenced + "\n\nThat is the first \(elementLimit) of \(elements.count) elements on "
            + "the page. Narrow the page down, or scroll and take another snapshot."
    }

    public static func decode(_ json: Data) throws -> [BrowserPageElement] {
        try JSONDecoder().decode([BrowserPageElement].self, from: json)
    }

    private static func line(_ element: BrowserPageElement, at index: Int) -> String {
        let reference = BrowserAgentReference(index: index)
        var said = ["- \(element.role) \"\(oneLine(element.name))\" [\(reference.token)]"]
        if element.isPassword {
            said.append("holds \(element.valueLength) characters")
        }
        if !element.isPassword, let value = element.value, !value.isEmpty {
            said.append("value \"\(oneLine(value))\"")
        }
        if element.isDisabled {
            said.append("(disabled)")
        }
        if let isChecked = element.isChecked {
            said.append(isChecked ? "(checked)" : "(not checked)")
        }
        return indent(element.depth) + said.joined(separator: " ")
    }

    private static func indent(_ depth: Int) -> String {
        String(repeating: "  ", count: min(max(depth, 0), depthLimit))
    }

    private static func oneLine(_ text: String) -> String {
        let flattened = BridgeUntrustedText.normalisingLineBreaks(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard flattened.count > nameLimit else { return flattened }
        return String(flattened.prefix(nameLimit)) + "…"
    }
}
