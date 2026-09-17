import CryptoKit
import Foundation

public enum UpdateInstaller {
    public static let appName = "UnifiedDev.app"

    public static let reopenCommand = "/usr/bin/open"

    public static let replacementWaitLimit = 600

    public enum Trouble: Error, Equatable, Sendable, CustomStringConvertible {
        case download(String)
        case sizeMismatch(expected: Int, actual: Int)
        case digestMismatch
        case unpack(String)
        case missingApp
        case versionMismatch(expected: String, actual: String?)
        case signature(String)
        case notNotarised(String)
        case notWritable(path: String)
        case translocated

        public var description: String {
            switch self {
            case .download(let reason): "The download did not finish: \(reason)"
            case .sizeMismatch(let expected, let actual):
                "The download is \(actual) bytes and the release says \(expected)."
            case .digestMismatch: "The download does not match the checksum GitHub published for it."
            case .unpack(let reason): "The download could not be unpacked: \(reason)"
            case .missingApp: "The download does not contain \(appName)."
            case .versionMismatch(let expected, let actual):
                "The download says it is version \(actual ?? "unknown"), not \(expected)."
            case .signature(let reason): "The download is not signed as this copy of Unified Dev is: \(reason)"
            case .notNotarised(let reason): "The download is not notarised by Apple: \(reason)"
            case .notWritable(let path): "Unified Dev cannot replace itself at \(path). Install the update from the release page."
            case .translocated:
                "Unified Dev is running from a temporary location macOS gave it. Move it to the Applications folder, open it from there, and check again."
            }
        }
    }

    public static func replaceability(of target: URL, fileManager: FileManager = .default) -> Trouble? {
        guard !target.path.contains("/AppTranslocation/") else { return .translocated }
        guard fileManager.isWritableFile(atPath: target.deletingLastPathComponent().path),
              fileManager.isWritableFile(atPath: target.path) else {
            return .notWritable(path: target.path)
        }
        return nil
    }

    public static func sha256Hex(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public static func verifyDownload(_ file: URL, against asset: GitHubRelease.Asset) throws {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? -1
        guard size == asset.size else {
            throw Trouble.sizeMismatch(expected: asset.size, actual: size)
        }
        guard let expected = asset.sha256 else { return }
        guard try sha256Hex(of: file) == expected else { throw Trouble.digestMismatch }
    }

    public static func stage(
        asset: GitHubRelease.Asset,
        version: ReleaseVersion,
        requirement: String,
        workDirectory: URL,
        session: URLSession = .shared
    ) async throws -> URL {
        guard asset.downloadURL.isFileURL || GitHubRelease.isGitHubURL(asset.downloadURL) else {
            throw Trouble.download("\(asset.downloadURL.absoluteString) is not a GitHub download")
        }
        try? FileManager.default.removeItem(at: workDirectory)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let archive = try await download(asset, into: workDirectory, session: session)
        try verifyDownload(archive, against: asset)
        return try await unpack(archive, version: version, requirement: requirement, into: workDirectory)
    }

    static func download(_ asset: GitHubRelease.Asset, into directory: URL, session: URLSession) async throws -> URL {
        let archive = directory.appending(path: asset.name)
        do {
            let (downloaded, response) = try await session.download(from: asset.downloadURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw Trouble.download("GitHub answered \(http.statusCode)")
            }
            try FileManager.default.moveItem(at: downloaded, to: archive)
        } catch let trouble as Trouble {
            throw trouble
        } catch {
            throw Trouble.download(error.localizedDescription)
        }
        return archive
    }

    static func unpack(
        _ archive: URL, version: ReleaseVersion, requirement: String, into directory: URL
    ) async throws -> URL {
        let unpacked = directory.appending(path: "unpacked")
        let unzip = try await Shell.run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])
        guard unzip.ok else { throw Trouble.unpack(unzip.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }

        let app = unpacked.appending(path: appName)
        guard FileManager.default.fileExists(atPath: app.appending(path: "Contents/Info.plist").path) else {
            throw Trouble.missingApp
        }

        let stamped = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let stamped, ReleaseVersion(stamped) == version else {
            throw Trouble.versionMismatch(expected: version.description, actual: stamped)
        }

        try await verifySignature(of: app, requirement: requirement)
        return app
    }

    public static func verifySignature(of app: URL, requirement: String) async throws {
        let result = try await Shell.run(
            "/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R=\(requirement)", app.path]
        )
        guard result.ok else {
            throw Trouble.signature(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public static func assessNotarisation(of app: URL) async throws {
        let result = try await Shell.run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path])
        guard result.ok else {
            throw Trouble.notNotarised(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    public static let replacementScript = """
    pid=$1
    staged=$2
    target=$3
    requirement=$4
    reopen=$5
    log=$6
    exec >>"$log" 2>&1
    print -r -- "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ) replacing $target"
    waited=0
    while /bin/kill -0 "$pid" 2>/dev/null; do
      if (( waited >= \(replacementWaitLimit) )); then print -r -- "gave up waiting for $pid"; exit 1; fi
      waited=$(( waited + 1 ))
      /bin/sleep 0.2
    done
    incoming=$(/usr/bin/mktemp -d "${target:h}/.UnifiedDev-update.XXXXXX") || { "$reopen" "$target"; exit 1; }
    fail() { print -r -- "$1"; /bin/rm -rf "$incoming"; "$reopen" "$target"; exit 1; }
    /usr/bin/ditto "$staged" "$incoming/new.app" || fail "the update could not be copied beside $target"
    /usr/bin/codesign --verify --deep --strict "-R=$requirement" "$incoming/new.app" || fail "the copied update failed its signature check"
    /bin/mv "$target" "$incoming/previous.app" || fail "the current copy could not be moved aside"
    if ! /bin/mv "$incoming/new.app" "$target"; then
      /bin/mv "$incoming/previous.app" "$target" && fail "the update could not be moved into place"
      print -r -- "the update and the restore both failed; the previous copy is at $incoming/previous.app"
      exit 1
    fi
    /bin/rm -rf "$incoming"
    print -r -- "replaced"
    "$reopen" "$target"
    """

    public struct Replacement: Equatable, Sendable {
        public let staged: URL
        public let target: URL
        public let requirement: String
        public let log: URL

        public init(staged: URL, target: URL, requirement: String, log: URL) {
            self.staged = staged
            self.target = target
            self.requirement = requirement
            self.log = log
        }
    }

    public static func replacementArguments(
        processID: Int32, replacement: Replacement, reopen: String = reopenCommand
    ) -> [String] {
        [
            "-f", "-c", replacementScript, "unifieddev-update",
            String(processID), replacement.staged.path, replacement.target.path,
            replacement.requirement, reopen, replacement.log.path,
        ]
    }

    @discardableResult
    public static func launchReplacement(
        processID: Int32, replacement: Replacement, reopen: String = reopenCommand
    ) throws -> Process {
        try FileManager.default.createDirectory(
            at: replacement.log.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = replacementArguments(processID: processID, replacement: replacement, reopen: reopen)
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": NSHomeDirectory()]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }
}
