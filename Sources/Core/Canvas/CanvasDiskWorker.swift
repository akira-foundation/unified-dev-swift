import Foundation

public actor CanvasDiskWorker {
    private let path: String

    public init(path: String) {
        self.path = path
    }

    public func perform(_ step: CanvasDiskStep) -> CanvasDiskResult {
        switch step {
        case .read: Self.read(path)
        case .save(let data, let expecting): Self.save(data, to: path, expecting: expecting)
        case .backup(let data): Self.backup(data, beside: path)
        }
    }

    public static func read(_ path: String) -> CanvasDiskResult {
        do {
            return .read(try CanvasDocumentFile.bytes(at: path))
        } catch {
            return .unreadable(error.localizedDescription)
        }
    }

    private static func save(_ data: Data, to path: String, expecting: [Data]?) -> CanvasDiskResult {
        do {
            if let expecting {
                guard let disk = try CanvasDocumentFile.bytes(at: path), expecting.contains(disk) else {
                    return .outsideChange
                }
            } else {
                try FileManager.default.createDirectory(
                    atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
                )
            }
            try data.write(to: URL(filePath: path), options: .atomic)
            return .written(data)
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    private static func backup(_ data: Data, beside path: String) -> CanvasDiskResult {
        do {
            return .backedUp(try CanvasDocumentFile.writeBackup(data, beside: path, at: Date()))
        } catch {
            return .backupFailed(error.localizedDescription)
        }
    }
}
