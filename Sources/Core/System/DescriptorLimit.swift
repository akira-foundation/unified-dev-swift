import Foundation

public enum DescriptorLimit {
    public static let ceiling: rlim_t = 10240

    static func target(soft: rlim_t, hard: rlim_t) -> rlim_t? {
        let wanted = min(hard, ceiling)
        return wanted > soft ? wanted : nil
    }

    public static func raise() {
        var limit = rlimit()
        guard getrlimit(RLIMIT_NOFILE, &limit) == 0,
              let wanted = target(soft: limit.rlim_cur, hard: limit.rlim_max) else { return }
        limit.rlim_cur = wanted
        setrlimit(RLIMIT_NOFILE, &limit)
    }
}
