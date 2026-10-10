import Foundation

public enum BrowserPageOutline {
    public static let elementLimit = 400

    public static let nameLimit = 120

    public static let roleLimit = 40

    public static let depthLimit = 4

    public static let unreadableAnswer =
        "That page did not answer browser_snapshot with a list Unified Dev could read. It may "
            + "have navigated while it was being read. Call browser_read, and try again once it "
            + "has settled."

    public static func render(_ survey: BrowserPageSurvey, from address: String) -> String {
        render(survey.elements, of: survey.total, from: address)
    }

    public static func render(
        _ elements: [BrowserPageElement], of total: Int? = nil, from address: String
    ) -> String {
        let counted = max(total ?? elements.count, elements.count)
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
        guard counted > elementLimit else { return fenced }
        return fenced + "\n\nThat is the first \(elementLimit) of \(counted) elements on the "
            + "page. Narrow the page down, or scroll and take another snapshot."
    }

    public static func troubled(_ trouble: String) -> String {
        trouble + " There is nothing on the page to point at. browser_read carries the same "
            + "fact, and browser_reload tries again."
    }

    public static func survey(_ answer: Any?) -> Result<BrowserPageSurvey, PaneRefusal> {
        guard let json = (answer as? String)?.data(using: .utf8),
              let survey = try? decode(json)
        else {
            return .failure(PaneRefusal(unreadableAnswer))
        }
        return .success(survey)
    }

    public static func decode(_ json: Data) throws -> BrowserPageSurvey {
        try JSONDecoder().decode(BrowserPageSurvey.self, from: json)
    }

    private static func line(_ element: BrowserPageElement, at index: Int) -> String {
        let reference = BrowserAgentReference(index: index)
        let named = flattened(element.name, to: nameLimit)
        let role = flattened(element.role, to: roleLimit)
        var said = ["- \(role) \"\(named)\" [\(reference.token)]"]
        if element.isPassword {
            said.append("holds \(element.valueLength) characters")
        }
        if !element.isPassword, let value = element.value, !value.isEmpty {
            said.append("value \"\(flattened(value, to: nameLimit))\"")
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

    static func flattened(_ text: String, to limit: Int) -> String {
        let oneLine = BridgeUntrustedText.normalisingLineBreaks(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .joined(separator: " ")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard oneLine.count > limit else { return oneLine }
        return String(oneLine.prefix(limit)) + "…"
    }
}
