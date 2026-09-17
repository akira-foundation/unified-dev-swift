import Foundation

public struct PaneNumberArgument: Sendable {
    public let name: String
    public let describedAs: String
    public let printedBy: String
    public let instead: String

    public init(name: String, describedAs: String, printedBy: String, instead: String) {
        self.name = name
        self.describedAs = describedAs
        self.printedBy = printedBy
        self.instead = instead
    }

    public func parse(_ raw: JSONValue?) -> Result<Int?, PaneRefusal> {
        switch raw {
        case .none, .null:
            return .success(nil)
        case .integer(let number):
            guard number >= 1 else {
                return .failure(
                    PaneRefusal(
                        "'\(name)' is \(describedAs), counting from 1. \(number) is not one of "
                            + "them."
                    )
                )
            }
            return .success(number)
        default:
            return .failure(
                PaneRefusal("'\(name)' is a whole number, as \(printedBy) prints it. \(instead)")
            )
        }
    }

    public static let browser = PaneNumberArgument(
        name: "browser",
        describedAs: "the number pane_list gives a browser",
        printedBy: "pane_list",
        instead: "Leave it out when there is only one browser open, and call pane_list first when "
            + "there is more than one."
    )

    public static let terminal = PaneNumberArgument(
        name: "terminal",
        describedAs: "the number pane_list gives a terminal",
        printedBy: "pane_list",
        instead: "Leave it out when only one terminal is open, and call pane_list first when there "
            + "is more than one."
    )

    public static let tab = PaneNumberArgument(
        name: "tab",
        describedAs: "a tab's place in the strip",
        printedBy: "workspace_tabs",
        instead: "Call workspace_tabs first and pass one of the numbers it gives."
    )
}
