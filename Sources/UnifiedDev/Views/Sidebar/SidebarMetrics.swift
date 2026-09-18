import SwiftUI

enum SidebarMetrics {
    static let headerLead: CGFloat = 8

    static let caretGutter: CGFloat = 11

    static let rowIndent: CGFloat = caretGutter + Metrics.spacing

    static let markColumn: CGFloat = Metrics.repoIcon

    static let markGap: CGFloat = 9

    static let nameColumn: CGFloat = rowIndent + markColumn + markGap

    static let subagentIndent: CGFloat = caretGutter

    static let crewIndent: CGFloat = nameColumn - markColumn / 2

    static let rowButton: CGFloat = 20

    static let hiddenDim: Double = 0.45

    static let caretSize: CGFloat = 9
}
