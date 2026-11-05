import Foundation
import Darwin

struct CanvasExportDirectory: ~Copyable {
    private let descriptor: Int32

    deinit {
        Darwin.close(descriptor)
    }

    static func canonicalPath(of path: String) -> String? {
        let descriptor = Darwin.open(path, O_RDONLY | O_DIRECTORY)
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }
        return location(of: descriptor)
    }

    static func open(creating path: String) throws -> CanvasExportDirectory {
        let name = (path as NSString).lastPathComponent
        let parentPath = (path as NSString).deletingLastPathComponent
        let parent = Darwin.open(parentPath, O_RDONLY | O_DIRECTORY)
        guard parent >= 0 else { throw CanvasExportWriteError.directory(reason(errno)) }
        defer { Darwin.close(parent) }
        guard location(of: parent) == parentPath else { throw CanvasExportRefusal.directoryMoved(name) }
        if mkdirat(parent, name, 0o755) != 0, errno != EEXIST {
            throw CanvasExportWriteError.directory(reason(errno))
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else { throw try failure(opening: name, in: parent, code: errno) }
        return CanvasExportDirectory(descriptor: descriptor)
    }

    func names() -> [String] {
        let duplicate = dup(descriptor)
        guard duplicate >= 0 else { return [] }
        guard let stream = fdopendir(duplicate) else {
            Darwin.close(duplicate)
            return []
        }
        defer { closedir(stream) }
        var names: [String] = []
        while let entry = readdir(stream) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(NAME_MAX) + 1) { String(cString: $0) }
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names
    }

    func isRegularFile(_ name: String) -> Bool {
        var status = stat()
        return fstatat(descriptor, name, &status, AT_SYMLINK_NOFOLLOW) == 0 && (status.st_mode & S_IFMT) == S_IFREG
    }

    func remove(_ name: String) throws {
        guard unlinkat(descriptor, name, 0) == 0 else { throw posixFailure(errno) }
    }

    func write(_ data: Data, as name: String) throws {
        let temporary = ".\(UUID().uuidString).tmp"
        let file = openat(descriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o644)
        guard file >= 0 else { throw posixFailure(errno) }
        do {
            try data.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let count = Darwin.write(file, buffer.baseAddress! + offset, buffer.count - offset)
                    guard count > 0 else { throw posixFailure(errno) }
                    offset += count
                }
            }
            guard fsync(file) == 0 else { throw posixFailure(errno) }
        } catch {
            Darwin.close(file)
            unlinkat(descriptor, temporary, 0)
            throw error
        }
        Darwin.close(file)
        guard renameat(descriptor, temporary, descriptor, name) == 0 else {
            let failure = posixFailure(errno)
            unlinkat(descriptor, temporary, 0)
            throw failure
        }
    }

    private static func failure(opening name: String, in parent: Int32, code: Int32) throws -> Error {
        switch code {
        case ELOOP:
            return CanvasExportRefusal.directoryIsSymbolicLink(name)
        case ENOTDIR:
            var status = stat()
            let isLink = fstatat(parent, name, &status, AT_SYMLINK_NOFOLLOW) == 0 && (status.st_mode & S_IFMT) == S_IFLNK
            return isLink ? CanvasExportRefusal.directoryIsSymbolicLink(name) : CanvasExportRefusal.directoryIsNotAFolder(name)
        default:
            return CanvasExportWriteError.directory(reason(code))
        }
    }

    private static func location(of descriptor: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(descriptor, F_GETPATH, &buffer) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func reason(_ code: Int32) -> String {
        String(cString: strerror(code))
    }
}

private func posixFailure(_ code: Int32) -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(code))])
}
