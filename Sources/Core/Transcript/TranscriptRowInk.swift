import Foundation

public enum TranscriptRowInk {
    private static let probeLength = 256

    private static let initMarker = Data("\"subtype\":\"init".utf8)

    public static func drawsNothing(kind: MessageKind, payload: Data) -> Bool {
        guard kind == .system else { return false }
        return payload.prefix(probeLength).range(of: initMarker) == nil
            && !BackgroundWake.isRow(kind: kind, payload: payload)
    }
}
