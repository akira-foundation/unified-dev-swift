import Foundation

public struct EditableFile: Sendable, Hashable {
    public let path: String
    public let text: String
    public let modifiedAt: Date
    public let size: Int

    public var filename: String { (path as NSString).lastPathComponent }
}

public enum FileEditorError: Error, Sendable, Equatable {
    case notAbsolute(String)
    case missing(String)
    case notText(String)
    case tooLarge(path: String, bytes: Int)
    case changedOnDisk(path: String, at: Date)
    case unreadable(path: String, reason: String)
    case unwritable(path: String, reason: String)
}

extension FileEditorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .notAbsolute(path):
            "\(path) is not an absolute path."
        case let .missing(path):
            "\((path as NSString).lastPathComponent) is no longer on disk."
        case let .notText(path):
            "\((path as NSString).lastPathComponent) is not UTF-8 text."
        case let .tooLarge(path, bytes):
            "\((path as NSString).lastPathComponent) is \(bytes / 1_048_576) MB, too large to edit here."
        case let .changedOnDisk(path, at):
            "\((path as NSString).lastPathComponent) changed on disk at "
                + "\(Self.clock.string(from: at)). Your edit was not saved."
        case let .unreadable(path, reason):
            "Could not read \((path as NSString).lastPathComponent): \(reason)"
        case let .unwritable(path, reason):
            "Could not save \((path as NSString).lastPathComponent): \(reason)"
        }
    }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

public enum FileEditor {
    public static let sizeLimit = 4 * 1_048_576

    private static let sniffLength = 8_000

    private struct Stamp: Equatable {
        var modifiedAt: Date
        var size: Int
    }

    public static func read(_ path: String) throws(FileEditorError) -> EditableFile {
        guard path.hasPrefix("/") else { throw FileEditorError.notAbsolute(path) }

        for _ in 0..<2 {
            let before = try stamp(path)
            guard before.size <= sizeLimit else {
                throw FileEditorError.tooLarge(path: path, bytes: before.size)
            }

            let data: Data
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: path), options: [.uncached])
            } catch {
                throw FileEditorError.unreadable(path: path, reason: error.localizedDescription)
            }

            let after = try stamp(path)
            guard before == after, data.count == after.size else { continue }

            guard !data.prefix(sniffLength).contains(0) else { throw FileEditorError.notText(path) }
            guard let text = String(data: data, encoding: .utf8) else {
                throw FileEditorError.notText(path)
            }
            return EditableFile(
                path: path, text: text, modifiedAt: after.modifiedAt, size: data.count
            )
        }
        throw FileEditorError.changedOnDisk(path: path, at: (try? stamp(path).modifiedAt) ?? Date())
    }

    public static func isEditable(_ path: String) -> Bool {
        guard path.hasPrefix("/"), let stamp = try? stamp(path), stamp.size <= sizeLimit else {
            return false
        }
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: sniffLength)) ?? Data()
        return !head.contains(0)
    }

    @discardableResult
    public static func write(
        _ text: String, over baseline: EditableFile
    ) throws(FileEditorError) -> EditableFile {
        let current = try read(baseline.path)
        guard current.text == baseline.text else {
            throw FileEditorError.changedOnDisk(path: baseline.path, at: current.modifiedAt)
        }

        let url = URL(fileURLWithPath: baseline.path)
        let mode = try? FileManager.default.attributesOfItem(atPath: baseline.path)[.posixPermissions]

        do {
            try Data(text.utf8).write(to: url, options: [.atomic])
        } catch {
            throw FileEditorError.unwritable(path: baseline.path, reason: error.localizedDescription)
        }
        if let mode {
            try? FileManager.default.setAttributes(
                [.posixPermissions: mode], ofItemAtPath: baseline.path
            )
        }
        return try read(baseline.path)
    }

    private static func stamp(_ path: String) throws(FileEditorError) -> Stamp {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            throw FileEditorError.missing(path)
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw FileEditorError.missing(path)
        }
        return Stamp(
            modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast,
            size: (attributes[.size] as? NSNumber)?.intValue ?? 0
        )
    }
}
