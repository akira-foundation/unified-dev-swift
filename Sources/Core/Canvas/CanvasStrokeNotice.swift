import Foundation

public enum CanvasStrokeNotice {
    public static func reduced() -> CanvasExportNotice {
        CanvasExportNotice(
            tone: .information,
            title: "A long stroke was simplified",
            lines: ["This stroke had more points than a canvas keeps. Corners and spikes were kept and runs of points close together were merged."]
        )
    }

    public static func refused(_ reason: String) -> CanvasExportNotice {
        CanvasExportNotice(tone: .warning, title: "The stroke was not added", lines: [reason])
    }
}
