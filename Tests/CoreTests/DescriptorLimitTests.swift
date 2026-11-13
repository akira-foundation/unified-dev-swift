import Foundation
import Testing
@testable import Core

private let unlimited = rlim_t.max >> 1

@Suite("Descriptor limit")
struct DescriptorLimitTests {
    @Test("the launchd default is raised to the ceiling when the hard limit allows it")
    func raisesTheLaunchdDefault() {
        #expect(DescriptorLimit.target(soft: 256, hard: unlimited) == DescriptorLimit.ceiling)
    }

    @Test("a hard limit below the ceiling is where the soft limit stops")
    func stopsAtTheHardLimit() {
        #expect(DescriptorLimit.target(soft: 256, hard: 1024) == 1024)
    }

    @Test("a soft limit already at or above the target is left alone", arguments: [
        (soft: rlim_t(10240), hard: unlimited),
        (soft: rlim_t(20000), hard: unlimited),
        (soft: rlim_t(1024), hard: rlim_t(1024)),
    ])
    func leavesAHigherLimitAlone(limits: (soft: rlim_t, hard: rlim_t)) {
        #expect(DescriptorLimit.target(soft: limits.soft, hard: limits.hard) == nil)
    }

    @Test("raising applies the target to this process")
    func raisingAppliesTheTarget() {
        DescriptorLimit.raise()

        var limit = rlimit()
        getrlimit(RLIMIT_NOFILE, &limit)
        #expect(limit.rlim_cur >= min(limit.rlim_max, DescriptorLimit.ceiling))
    }
}
