import AppKit
import Foundation
import QuartzCore
import Core

@MainActor
enum IdleProbe {
    private static let harness = ProbeHarness(subject: "idle")

    static var isRequested: Bool { harness.isRequested }

    private static var base: String { ProbeHarness.text("--idle-base", or: "main") }
    private static var passes: Int { ProbeHarness.count("--idle-passes", or: 5) }

    private static var worktrees: [String] {
        guard let path = ProbeHarness.value(for: "--idle-worktrees"),
              let text = try? String(contentsOfFile: path, encoding: .utf8)
        else { return [] }
        return text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { FileManager.default.fileExists(atPath: $0 + "/.git") }
    }

    static func schedule() {
        Task { @MainActor in await run() }
    }

    private static func run() async {
        await harness.settle()

        let trees = worktrees
        guard !trees.isEmpty else { harness.fail("no worktrees to probe") }

        _ = await pass(trees)

        var runs: [Pass] = []
        for _ in 0..<passes {
            runs.append(await pass(trees))
        }

        let own: [String: JSONValue] = [
            "worktrees": .integer(trees.count),
            "base": .string(base),
            "passes": .array(runs.map(\.json)),
            "median": .object([
                "wallMs": .number(median(runs.map(\.wallMs))),
                "cpuMs": .number(median(runs.map { $0.cpu.total * 1000 })),
                "spawns": .number(median(runs.map { Double($0.spawns) })),
                "spawnsPerWorktree": .number(
                    median(runs.map { Double($0.spawns) / Double(trees.count) })
                ),
            ]),
        ]
        harness.write(
            .object(own.merging(harness.conditions(window: nil)) { mine, _ in mine }), echo: true
        )
        exit(0)
    }

    private struct Pass {
        var wallMs: Double
        var cpu: ProcessCPU.Sample
        var spawns: Int

        var json: JSONValue {
            .object([
                "wallMs": .number(wallMs),
                "cpuMs": .number(cpu.total * 1000),
                "selfCpuMs": .number(cpu.own * 1000),
                "childCpuMs": .number(cpu.children * 1000),
                "spawns": .integer(spawns),
            ])
        }
    }

    private static func pass(_ trees: [String]) async -> Pass {
        let spawnsBefore = Shell.spawnCount
        let cpuBefore = ProcessCPU.read()
        let wallBefore = CACurrentMediaTime()

        let baseBranch = base
        await withTaskGroup(of: Void.self) { group in
            var next = trees.startIndex
            var running = 0
            while next < trees.endIndex || running > 0 {
                while running < DiffRefreshSchedule.width, next < trees.endIndex {
                    let tree = trees[next]
                    next = trees.index(after: next)
                    running += 1
                    group.addTask { _ = try? await Git.diffStat(worktree: tree, base: baseBranch) }
                }
                guard await group.next() != nil else { break }
                running -= 1
            }
        }

        return Pass(
            wallMs: (CACurrentMediaTime() - wallBefore) * 1000,
            cpu: ProcessCPU.read() - cpuBefore,
            spawns: Shell.spawnCount - spawnsBefore
        )
    }

    private static func median(_ values: [Double]) -> Double {
        ProbeStats.percentile(0.5, of: values.sorted())
    }
}

enum ProcessCPU {
    struct Sample {
        var own: Double
        var children: Double

        var total: Double { own + children }

        static func - (lhs: Sample, rhs: Sample) -> Sample {
            Sample(own: lhs.own - rhs.own, children: lhs.children - rhs.children)
        }
    }

    static func read() -> Sample {
        Sample(own: seconds(of: RUSAGE_SELF), children: seconds(of: RUSAGE_CHILDREN))
    }

    private static func seconds(of who: Int32) -> Double {
        var usage = rusage()
        guard getrusage(who, &usage) == 0 else { return 0 }
        return interval(usage.ru_utime) + interval(usage.ru_stime)
    }

    private static func interval(_ value: timeval) -> Double {
        Double(value.tv_sec) + Double(value.tv_usec) / 1_000_000
    }
}
