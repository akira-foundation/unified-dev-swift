import SwiftUI
import Core

struct CheckRunSnapshotGallery: View {
    private static let column: CGFloat = 380

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            group("Eleven passed, two running: the reported case") {
                rows(Self.branch)
            }

            group("Every state, in the order they occur") {
                rows(Self.everyState)
            }

            group("On a selected row, where the tint is dropped") {
                VStack(spacing: 0) {
                    ForEach(Self.everyState) { run in
                        CheckRunRow(run: run)
                            .background(Palette.selectedEmphasized)
                            .environment(\.isOnEmphasizedSelection, true)
                    }
                }
                .frame(width: Self.column, alignment: .leading)
            }
        }
        .padding(16)
    }

    private func rows(_ runs: [CheckRun]) -> some View {
        VStack(spacing: 0) {
            ForEach(runs) { CheckRunRow(run: $0) }
        }
        .frame(width: Self.column, alignment: .leading)
        .background(Palette.surface)
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.caption)
            content()
        }
    }

    private static let started = Date(timeIntervalSince1970: 1_770_000_000)

    private static func passed(_ name: String, seconds: TimeInterval) -> CheckRun {
        CheckRun(
            name: name,
            status: "COMPLETED",
            conclusion: "SUCCESS",
            detailsURL: "https://example.invalid/\(name)",
            startedAt: started,
            completedAt: started.addingTimeInterval(seconds),
            workflowName: "tests"
        )
    }

    private static func running(_ name: String) -> CheckRun {
        CheckRun(
            name: name,
            status: "IN_PROGRESS",
            conclusion: "",
            detailsURL: "https://example.invalid/\(name)",
            startedAt: started,
            workflowName: "tests"
        )
    }

    private static let branch: [CheckRun] = [
        passed("build (macos-15)", seconds: 214),
        passed("build (macos-26)", seconds: 233),
        running("lint"),
        passed("unit (Core)", seconds: 61),
        passed("unit (BridgeShim)", seconds: 44),
        passed("unit (Store)", seconds: 96),
        passed("unit (Git)", seconds: 132),
        running("integration"),
        passed("spell", seconds: 8),
        passed("house rules", seconds: 5),
        passed("appcast", seconds: 12),
        passed("notarise", seconds: 401),
        passed("danger", seconds: 19),
    ]

    private static let everyState: [CheckRun] = [
        CheckRun(name: "Queued", status: "QUEUED", conclusion: "", workflowName: "tests"),
        running("Running"),
        passed("Passed", seconds: 61),
        CheckRun(
            name: "Failed",
            status: "COMPLETED",
            conclusion: "FAILURE",
            startedAt: started,
            completedAt: started.addingTimeInterval(31),
            workflowName: "tests"
        ),
        CheckRun(name: "Skipped", status: "COMPLETED", conclusion: "SKIPPED", workflowName: "tests"),
        CheckRun(name: "No result", status: "COMPLETED", conclusion: "", workflowName: "tests"),
    ]
}
