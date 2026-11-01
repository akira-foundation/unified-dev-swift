import SwiftUI
import Core

struct BackgroundTasksView: View {
    let model: WorkspaceModel

    @State private var opened: OpenedTask?

    var body: some View {
        let transcript = model.tasksTranscript
        let isRunning = transcript?.subagents.isAnythingRunning ?? false
        TimelineView(.periodic(from: .now, by: isRunning ? 1 : 3600)) { context in
            let list = transcript.map {
                BackgroundTaskList($0.subagents, stopsTasks: $0.stopsBackgroundTasks, now: context.date)
            }
            List {
                ForEach(list?.rows ?? []) { row in
                    BackgroundTaskRow(
                        row: row,
                        onOpen: { opened = OpenedTask(id: row.id) },
                        onStop: { transcript?.stopBackgroundTask(row.id) }
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $opened) { task in
            BackgroundTaskSheet(model: model, transcript: transcript, id: task.id)
        }
    }
}

private struct OpenedTask: Identifiable {
    let id: SubagentID
}

private struct BackgroundTaskSheet: View {
    let model: WorkspaceModel
    let transcript: TranscriptModel?
    let id: SubagentID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SubagentOutputView(model: model, target: .live(id), offersComposer: false, source: transcript)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 360, idealHeight: 520)
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
