import Foundation

public enum CanvasDiskReconcile {
    public enum Outcome: Sendable, Equatable {
        case unchanged
        case reload(CanvasDocument, keepBackup: Bool)
        case refused(String)
        case vanished
    }

    public static func decide(disk: Data?, lastWritten: Data?, held: CanvasDocument, writing: Data? = nil) -> Outcome {
        guard let disk else { return .vanished }
        if disk == lastWritten || disk == writing { return .unchanged }
        switch CanvasDocumentCodec.decode(disk) {
        case .corrupt(let reason):
            return .refused("The file on disk cannot be read: \(reason)")
        case .newerVersion(let version):
            return .refused(
                "The file on disk was saved as version \(version), and this Unified Dev reads up to version \(CanvasDocument.currentVersion)."
            )
        case .document(let document):
            return .reload(document, keepBackup: !sameContent(document, held))
        }
    }

    private static func sameContent(_ first: CanvasDocument, _ second: CanvasDocument) -> Bool {
        guard let firstBytes = try? CanvasDocumentCodec.encode(first),
              let secondBytes = try? CanvasDocumentCodec.encode(second) else { return false }
        return firstBytes == secondBytes
    }
}
