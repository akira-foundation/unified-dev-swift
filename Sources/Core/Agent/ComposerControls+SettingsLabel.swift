import Foundation

extension ComposerControls {
    public func settingsLabel(model: String) -> String {
        guard offersInteractionMode, interactionMode == .plan else { return model }
        return "\(model), \(InteractionMode.plan.label)"
    }
}
