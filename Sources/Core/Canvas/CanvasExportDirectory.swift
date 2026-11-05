import Foundation
import Darwin

struct CanvasExportDirectory: ~Copyable {
    private let descriptor: Int32

    deinit {
        Darwin.close(descriptor)
    }

    static func open(creating path: String) throws -> CanvasExportDirectory {
        let name = (path as NSString).lastPathComponent
        let parentPath = (path as NSString).deletingLastPathComponent
        let parent = Darwin.open(parentPath, O_RDONLY | O_DIRECTORY)
        guard parent >= 0 else { throw CanvasExportWriteError.directory(String(cString: strerror(errno))) }
        defer { Darwin.close(parent) }
        guard location(of: parent) == parentPath else { throw CanvasExportRefusal.directoryMoved(name) }
        if mkdirat(parent, name, 0o755) != 0, errno != EEXIST {
            throw CanvasExportWriteError.directory(String(cString: strerror(errno)))
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            var status = stat()
            let isLink = fstatat(parent, name, &status, AT_SYMLINK_NOFOLLOW) == 0 && (status.st_mode & S_IFMT) == S_IFLNK
            throw isLink ? CanvasExportRefusal.directoryIsSymbolicLink(name) : CanvasExportRefusal.directoryIsNotAFolder(name)
        }
        guard location(of: descriptor) == path else {
            Darwin.close(descriptor)
            throw CanvasExportRefusal.directoryMoved(name)
        }
        return CanvasExportDirectory(descriptor: descriptor)
    }

    func names() -> [String] {
        let duplicate = dup(descriptor)
        guard duplicate >= 0, let stream = fdopendir(duplicate) else { return [] }
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
        guard unlinkat(descriptor, name, 0) == 0 else { throw posixFailure() }
    }

    func write(_ data: Data, as name: String) throws {
        let temporary = ".\(UUID().uuidString).tmp"
        let file = openat(descriptor, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o644)
        guard file >= 0 else { throw posixFailure() }
        do {
            try data.withUnsafeBytes { buffer in
                var offset = 0
                while offset < buffer.count {
                    let count = Darwin.write(file, buffer.baseAddress! + offset, buffer.count - offset)
                    guard count > 0 else { throw posixFailure() }
                    offset += count
                }
            }
            guard fsync(file) == 0 else { throw posixFailure() }
            Darwin.close(file)
            guard renameat(descriptor, temporary, descriptor, name) == 0 else { throw posixFailure() }
        } catch {
            Darwin.close(file)
            unlinkat(descriptor, temporary, 0)
            throw error
        }
    }

    private static func location(of descriptor: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(descriptor, F_GETPATH, &buffer) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

private func posixFailure() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
}
