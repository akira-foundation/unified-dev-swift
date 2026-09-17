import CryptoKit
import Foundation

public enum UpdateInstaller {
    public static let appName = "UnifiedDev.app"

    public enum Trouble: Error, Equatable, Sendable, CustomStringConvertible {
        case download(String)
        case sizeMismatch(expected: Int, actual: Int)
        case digestMismatch
        case unpack(String)
        case missingApp
        case versionMismatch(expected: String, actual: String?)
        case signature(String)
        case notWritable(path: String)

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
            case .signature(let reason): "The download is not signed by the same developer as this copy: \(reason)"
            case .notWritable(let path): "Unified Dev cannot replace itself at \(path). Install the update from the release page."
            }
        }
    }

    public static func signatureRequirement(teamID: String) -> String {
        "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    public static func canReplace(bundleAt target: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.isWritableFile(atPath: target.deletingLastPathComponent().path)
            && fileManager.isWritableFile(atPath: target.path)
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
        teamID: String,
        workDirectory: URL,
        session: URLSession = .shared
    ) async throws -> URL {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: workDirectory)
        try fileManager.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        let archive = workDirectory.appending(path: asset.name)
        do {
            let (downloaded, response) = try await session.download(from: asset.downloadURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw Trouble.download("GitHub answered \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            try fileManager.moveItem(at: downloaded, to: archive)
        } catch let trouble as Trouble {
            throw trouble
        } catch {
            throw Trouble.download(error.localizedDescription)
        }

        try verifyDownload(archive, against: asset)

        let unpacked = workDirectory.appending(path: "unpacked")
        let unzip = try await Shell.run("ditto", ["-x", "-k", archive.path, unpacked.path])
        guard unzip.ok else { throw Trouble.unpack(unzip.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }

        let app = unpacked.appending(path: appName)
        guard fileManager.fileExists(atPath: app.appending(path: "Contents/Info.plist").path) else {
            throw Trouble.missingApp
        }

        let stamped = Bundle(url: app)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let stamped, ReleaseVersion(stamped) == version else {
            throw Trouble.versionMismatch(expected: version.description, actual: stamped)
        }

        let signature = try await Shell.run(
            "codesign",
            ["--verify", "--deep", "--strict", "-R=\(signatureRequirement(teamID: teamID))", app.path]
        )
        guard signature.ok else {
            throw Trouble.signature(signature.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return app
    }

    public static let replacementScript = """
    pid=$1
    staged=$2
    target=$3
    while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
    incoming="$target.incoming"
    previous="$target.previous"
    rm -rf "$incoming" "$previous"
    if ! /usr/bin/ditto "$staged" "$incoming"; then rm -rf "$incoming"; /usr/bin/open "$target"; exit 1; fi
    if ! /bin/mv "$target" "$previous"; then rm -rf "$incoming"; /usr/bin/open "$target"; exit 1; fi
    if ! /bin/mv "$incoming" "$target"; then /bin/mv "$previous" "$target"; /usr/bin/open "$target"; exit 1; fi
    rm -rf "$previous"
    /usr/bin/open "$target"
    """

    public static func replacementArguments(processID: Int32, staged: URL, target: URL) -> [String] {
        ["-c", replacementScript, "unifieddev-update", String(processID), staged.path, target.path]
    }

    public static func launchReplacement(processID: Int32, staged: URL, target: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/zsh")
        process.arguments = replacementArguments(processID: processID, staged: staged, target: target)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
}
