import Foundation

public enum TerminalExit: Sendable, Hashable {
    case exited(Int32)
    case killed(Int32)
    case unknown

    public init(waitStatus: Int32?) {
        guard let status = waitStatus else {
            self = .unknown
            return
        }

        let signal = status & 0x7F
        switch signal {
        case 0: self = .exited((status >> 8) & 0xFF)
        case 0x7F: self = .unknown
        default: self = .killed(signal)
        }
    }

    public var closesPane: Bool {
        self == .exited(0)
    }

    public var paneMessage: String {
        switch self {
        case .exited(0), .unknown:
            "Process finished"
        case .exited(let status):
            "Process finished with status \(status)"
        case .killed(let signal):
            "Process killed by \(Self.name(ofSignal: signal))"
        }
    }

    static func name(ofSignal signal: Int32) -> String {
        let names: [Int32: String] = [
            SIGHUP: "SIGHUP",
            SIGINT: "SIGINT",
            SIGQUIT: "SIGQUIT",
            SIGILL: "SIGILL",
            SIGTRAP: "SIGTRAP",
            SIGABRT: "SIGABRT",
            SIGFPE: "SIGFPE",
            SIGKILL: "SIGKILL",
            SIGBUS: "SIGBUS",
            SIGSEGV: "SIGSEGV",
            SIGSYS: "SIGSYS",
            SIGPIPE: "SIGPIPE",
            SIGALRM: "SIGALRM",
            SIGTERM: "SIGTERM",
            SIGXCPU: "SIGXCPU",
            SIGXFSZ: "SIGXFSZ",
        ]
        return names[signal] ?? "signal \(signal)"
    }
}
