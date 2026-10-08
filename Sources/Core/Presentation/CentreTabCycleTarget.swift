import Foundation

public enum CentreTabCycleTarget {
    public struct Press: Sendable, Equatable {
        public var role: WindowDismissal.Role
        public var identifier: String?
        public var isSheet: Bool
        public var isPanel: Bool
        public var isEditingText: Bool
        public var isEditingThePrompt: Bool

        public init(
            role: WindowDismissal.Role = .workspace,
            identifier: String? = nil,
            isSheet: Bool = false,
            isPanel: Bool = false,
            isEditingText: Bool = false,
            isEditingThePrompt: Bool = false
        ) {
            self.role = role
            self.identifier = identifier
            self.isSheet = isSheet
            self.isPanel = isPanel
            self.isEditingText = isEditingText
            self.isEditingThePrompt = isEditingThePrompt
        }
    }

    public static func cycles(_ press: Press, mainSceneID: String) -> Bool {
        guard press.role == .workspace, !press.isSheet, !press.isPanel else { return false }
        guard let identifier = press.identifier,
              identifier == mainSceneID || identifier.hasPrefix(mainSceneID + "-")
        else { return false }
        return !press.isEditingText || press.isEditingThePrompt
    }
}
