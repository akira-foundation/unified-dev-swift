import SwiftUI
import Core

struct BackgroundTasksView: View {
    let model: WorkspaceModel

    @State private var opened: OpenedTask?

    var body: some View {
        let transcript = model.tasksTranscript
        let isRunning = transcript?.subagents.isAnythingRunning ?? false
        TimelineView(.periodic(from: .now, by: isRunning ? 1 : 3600)) { context in
            let list = transcript?.backgroundTaskList(now: context.date)
            BackgroundTaskListBody(
                list: list ?? BackgroundTaskList(SubagentRoster()),
                onOpen: { opened = OpenedTask(id: $0) },
                onStop: { transcript?.stopBackgroundTask($0) },
                onClear: { model.clearFinishedTasks() }
            )
        }
        .sheet(item: $opened) { task in
            BackgroundTaskSheet(model: model, transcript: transcript, id: task.id)
        }
    }
}

private struct OpenedTask: Identifiable {
    let id: SubagentID
}

struct BackgroundTaskListBody: View {
    var list: BackgroundTaskList
    var onOpen: @MainActor (SubagentID) -> Void
    var onStop: @MainActor (SubagentID) -> Void
    var onClear: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if list.canClear {
                HStack {
                    Spacer(minLength: 0)
                    Button("Clear", action: onClear)
                        .buttonStyle(.glass)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.accent)
                        .help("Remove the finished tasks from this list")
                }
                .padding(.horizontal, InspectorLayout.inset)
                .padding(.vertical, Metrics.spacingSmall)
                Hairline()
            }

            List {
                section("Running", list.running)
                section("Finished", list.finished)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ rows: [BackgroundTaskList.Row]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    BackgroundTaskRow(
                        row: row,
                        onOpen: { onOpen(row.id) },
                        onStop: { onStop(row.id) }
                    )
                }
            }
        }
    }
}

private struct BackgroundTaskRow: View {
    var row: BackgroundTaskList.Row
    var onOpen: @MainActor () -> Void
    var onStop: @MainActor () -> Void

    var body: some View {
        HStack(spacing: Metrics.spacingWide) {
            Button(action: onOpen) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(Typo.body)
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(row.detail)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                } icon: {
                    SubagentMarkGlyph(mark: row.mark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(row.openHelp)

            if row.canStop {
                Button("Stop", role: .destructive, action: onStop)
                    .controlSize(.small)
                    .help("Stop this background task")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(row.title))
        .accessibilityValue(Text(row.detail))
    }
}
