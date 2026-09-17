import Foundation

public enum WorkspaceTabChoice: Sendable, Equatable {
    case number(Int)
    case title(String)

    public static func parse(
        number rawNumber: JSONValue?, title rawTitle: JSONValue?
    ) -> Result<WorkspaceTabChoice, PaneRefusal> {
        let title: String?
        switch rawTitle {
        case .none, .null:
            title = nil
        case .string(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            title = trimmed.isEmpty ? nil : trimmed
        default:
            return .failure(
                PaneRefusal(
                    "'title' is the name workspace_tabs prints for a tab, as text. Pass 'tab' "
                        + "instead to name one by its number."
                )
            )
        }

        let number: Int?
        switch PaneNumberArgument.tab.parse(rawNumber) {
        case .failure(let refusal): return .failure(refusal)
        case .success(let value): number = value
        }

        switch (number, title) {
        case (let number?, nil):
            return .success(.number(number))
        case (nil, let title?):
            return .success(.title(title))
        case (nil, nil):
            return .failure(
                PaneRefusal(
                    "workspace_tab_select needs to know which tab. Pass 'tab' as the number "
                        + "workspace_tabs prints, or 'title' as the name the strip shows."
                )
            )
        case (.some, .some):
            return .failure(
                PaneRefusal(
                    "Pass 'tab' or 'title', not both. They are two ways of naming one tab, and a "
                        + "call that gives both has not said which it means."
                )
            )
        }
    }

    public static func choose(
        _ choice: WorkspaceTabChoice, among tabs: [WorkspaceTabReport]
    ) -> Result<WorkspaceTabReport, PaneRefusal> {
        guard !tabs.isEmpty else {
            return .failure(
                PaneRefusal(
                    "That workspace has nothing open in the centre column, so there is no tab to "
                        + "bring forward. pane_open is what opens one."
                )
            )
        }

        switch choice {
        case .number(let number):
            guard let found = tabs.first(where: { $0.number == number }) else {
                return .failure(
                    PaneRefusal(
                        "There is no tab \(number) in this workspace. The tabs are \(list(tabs)). "
                            + "The numbers move as tabs are opened and closed, so call "
                            + "workspace_tabs again."
                    )
                )
            }
            return .success(found)

        case .title(let title):
            let matches = tabs.filter { $0.title.caseInsensitiveCompare(title) == .orderedSame }
            guard !matches.isEmpty else {
                return .failure(
                    PaneRefusal(
                        "This workspace has no tab called '\(title)'. The tabs are \(list(tabs))."
                    )
                )
            }
            guard matches.count == 1 else {
                return .failure(
                    PaneRefusal(
                        "\(matches.count) tabs are called '\(title)': "
                            + "\(list(matches)). Pass 'tab' with the number of the one you mean."
                    )
                )
            }
            return .success(matches[0])
        }
    }

    private static func list(_ tabs: [WorkspaceTabReport]) -> String {
        let shown = tabs.prefix(10).map { "\($0.number) '\($0.title)' (\($0.kind.rawValue))" }
        let rest = tabs.count - shown.count
        let text = shown.joined(separator: ", ")
        return rest > 0 ? text + ", and \(rest) more" : text
    }
}

public enum WorkspaceTabSelection: Sendable, Equatable {
    case selected(String)
    case refused(String)

    public static func alreadyInFront(_ tab: WorkspaceTabReport) -> WorkspaceTabSelection {
        .selected("'\(tab.title)' was already the tab in front. Nothing moved.")
    }

    public static func brought(_ tab: WorkspaceTabReport) -> WorkspaceTabSelection {
        let extra = tab.kind == .chat
            ? " It is the workspace's active conversation now, as it would be if they had clicked it."
            : ""
        return .selected("Brought '\(tab.title)' to the front of the strip.\(extra)")
    }
}
