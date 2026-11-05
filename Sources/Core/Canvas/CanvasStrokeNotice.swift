import Foundation

public enum CanvasStrokeNotice {
    public static func after(refusal: String?, reduced: Bool) -> CanvasNotice? {
        if let refusal {
            return CanvasNotice(tone: .warning, title: "The stroke was not added", lines: [refusal])
        }
        guard reduced else { return nil }
        return CanvasNotice(
            tone: .information,
            title: "A long stroke lost some detail",
            lines: ["This stroke had too many points to keep at the pen's detail, so some detail was smoothed away."]
        )
    }
}
