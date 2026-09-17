import Foundation
import Observation
import SwiftUI
import Core

@MainActor
@Observable
final class SetupInspection {
    private(set) var truth = SetupReport.pending
    private(set) var shown = SetupReport.pending

    private(set) var isRunning = false

    private static let stagger = Duration.milliseconds(140)

    var revealsInstantly = false

    private var run: Task<Void, Never>?
    private var revealRun: Task<Void, Never>?
    private var isPresentingChecks = false
    private var hasProbed = false
    private let rehearsal: SetupReport?
    private let agentOverrides: () async -> [AgentKind: String]

    init(
        rehearsal: SetupReport? = nil,
        agentOverrides: @escaping () async -> [AgentKind: String] = { [:] }
    ) {
        self.rehearsal = rehearsal
        self.agentOverrides = agentOverrides
    }

    func start() {
        guard run == nil else { return }
        revealRun?.cancel()
        revealRun = nil
        truth = .pending
        shown = .pending
        hasProbed = false
        isRunning = true
        run = Task { [weak self] in
            await self?.probe()
            guard let self else { return }
            self.hasProbed = true
            self.run = nil
            if self.isPresentingChecks {
                self.beginReveal()
            } else {
                self.isRunning = false
            }
        }
    }

    func presentChecks() {
        isPresentingChecks = true
        guard hasProbed, revealRun == nil, !shown.isSettled else { return }
        beginReveal()
    }

    func dismissChecks() {
        isPresentingChecks = false
    }

    func cancel() {
        run?.cancel()
        run = nil
        revealRun?.cancel()
        revealRun = nil
        isRunning = false
    }

    private func beginReveal() {
        isRunning = true
        revealRun = Task { [weak self] in
            await self?.reveal()
            self?.revealRun = nil
            self?.isRunning = false
        }
    }

    private func probe() async {
        if let rehearsal {
            for check in rehearsal.checks { record(check) }
        } else {
            let probe = SetupProbe(agentOverrides: await agentOverrides())
            for await check in probe.run() {
                if Task.isCancelled { return }
                record(check)
            }
        }
    }

    private func record(_ check: SetupCheck) {
        var checks = truth.checks
        if let index = checks.firstIndex(where: { $0.tool == check.tool }) {
            checks[index] = check
        }
        truth = SetupReport(checks: checks)
    }

    private func reveal() async {
        for tool in SetupTool.displayOrder {
            if Task.isCancelled { return }
            if !revealsInstantly, tool != SetupTool.displayOrder.first {
                try? await Task.sleep(for: Self.stagger)
                if Task.isCancelled { return }
            }
            var checks = shown.checks
            if let index = checks.firstIndex(where: { $0.tool == tool }) {
                checks[index] = SetupCheck(tool: tool, outcome: truth.outcome(for: tool))
            }
            let next = SetupReport(checks: checks)
            if revealsInstantly || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                shown = next
            } else {
                withAnimation(Motion.arrival) { shown = next }
            }
        }
    }
}
