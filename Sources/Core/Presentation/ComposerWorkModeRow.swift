import Foundation

public enum ComposerWorkModeRow: Equatable, Sendable {
    case choice
    case offerBuild
    case build

    public init(isPlanningAvailable: Bool, interactionMode: InteractionMode) {
        guard !isPlanningAvailable else {
            self = .choice
            return
        }
        self = interactionMode == .plan ? .offerBuild : .build
    }
}
