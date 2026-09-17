import Foundation
import Core

@MainActor
final class CrashReportingService {
    static let shared = CrashReportingService()
    private var installed = false

    func start() {
        guard !installed else { return }
        SystemDefaults.registerOnce()
        let identity = BuildIdentity.read(from: .main)
        guard CrashReporting.isEligible(
            bundleIdentifier: Bundle.main.bundleIdentifier,
            identity: identity,
            enabled: UserDefaults.standard.bool(forKey: CrashReporting.settingKey),
            debuggerAttached: Self.debuggerAttached
        ) else { return }

        NSSetUncaughtExceptionHandler(Self.handle)
        installed = true
    }

    private static let handle: @convention(c) (NSException) -> Void = { exception in
        let report = CrashReportingService.report(for: exception, build: BuildIdentity.read(from: .main).line)
        _ = try? CrashLogWriter.write(report)
    }

    static var directory: URL? { try? CrashLogWriter.directory() }

    static func report(for exception: NSException, build: String) -> String {
        """
        build: \(build)
        bundle: \(Bundle.main.bundleIdentifier ?? "unbundled")
        name: \(exception.name.rawValue)
        reason: \(exception.reason ?? "none given")

        \(exception.callStackSymbols.joined(separator: "\n"))
        """
    }

    private static var debuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, UInt32(name.count), &info, &size, nil, 0) == 0 else { return true }
        return info.kp_proc.p_flag & P_TRACED != 0
    }
}

enum CrashLogWriter {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = base
            .appendingPathComponent(Store.databaseDirectoryName(forBundleIdentifier: Bundle.main.bundleIdentifier))
            .appendingPathComponent("CrashReports")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @discardableResult
    static func write(_ report: String, at instant: Date = Date()) throws -> URL {
        let directory = try directory()
        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        let file = directory.appendingPathComponent(CrashLogName.forReport(at: instant, existing: existing))
        try report.write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
