import Foundation

public enum InspectorTransition {
    public static func isAnimated(motionAllowed: Bool, contentIsChanging: Bool) -> Bool {
        motionAllowed && !contentIsChanging
    }
}
