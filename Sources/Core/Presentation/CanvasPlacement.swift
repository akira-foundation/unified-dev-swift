import Foundation

public enum CanvasPlacement: Sendable, Equatable {
    case retarget(bringToFront: Bool)
    case besideCaller
    case newTab(inFront: Bool)

    public static func decide(
        hasCanvas: Bool, focus: Bool, hasCaller: Bool, hasTabInFront: Bool
    ) -> CanvasPlacement {
        if hasCanvas { return .retarget(bringToFront: focus) }
        if focus && hasCaller { return .besideCaller }
        return .newTab(inFront: focus || !hasTabInFront)
    }
}
