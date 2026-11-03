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
        guard let expecting else { return saveOver(data, at: path) }
        do {
            guard let disk = try CanvasDocumentFile.bytes(at: path), expecting.contains(disk) else {
                return .outsideChange
            }
            try data.write(to: URL(filePath: path), options: .atomic)
            return .written(data)
        } catch {
            return .writeFailed(error.localizedDescription)
        }
    }

    private static func saveOver(_ data: Data, at path: String) -> CanvasDiskResult {
        let backup: String?
        do {
            let disk = try CanvasDocumentFile.bytes(at: path)
            backup = try disk.flatMap { $0 == data ? nil : try CanvasDocumentFile.writeBackup($0, beside: path, at: Date()) }
        } catch {
            return .saveOverRefused(error.localizedDescription)
        }
        do {
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true
            )
            try data.write(to: URL(filePath: path), options: .atomic)
            return backup.map { .savedOver(data, backup: $0) } ?? .written(data)
        } catch {
            return backup.map { .saveOverFailed(error.localizedDescription, backup: $0) }
                ?? .writeFailed(error.localizedDescription)
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
