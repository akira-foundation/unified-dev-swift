import Foundation

public enum PaneMeasure {
    public static let step: CGFloat = 8

    public static func room(_ height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return max(step, (height / step).rounded(.down) * step)
    }

    public static func chrome(_ height: CGFloat) -> CGFloat {
        guard height > 0 else { return 0 }
        return (height / step).rounded(.up) * step
    }

    public static func chrome(_ height: CGFloat, knowing known: CGFloat) -> CGFloat {
        let measured = chrome(height)
        return measured > 0 ? measured : known
    }

    public static func editorCap(
        room: CGFloat, chrome: CGFloat, floor: CGFloat, atLeast line: CGFloat
    ) -> CGFloat {
        guard room > 0 else { return .greatestFiniteMagnitude }
        return max(room - chrome - floor, line)
    }
}
