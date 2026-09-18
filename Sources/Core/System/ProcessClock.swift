import Foundation

public enum ProcessClock {
    public static func millisecondsSinceStart() -> Int {
        Int((Date().timeIntervalSince1970 - start) * 1000)
    }

    private static let start: TimeInterval = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0 else { return Date().timeIntervalSince1970 }
        let started = info.kp_proc.p_starttime
        return TimeInterval(started.tv_sec) + TimeInterval(started.tv_usec) / 1_000_000
    }()
}
