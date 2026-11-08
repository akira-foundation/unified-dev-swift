import SwiftUI
import Core

struct ArchiveRetentionSettingsSection: View {
    @Environment(AppModel.self) private var app

    @State private var retention = ArchiveRetention()
    @State private var expired: [ArchivedWorkspaceFootprint]?
    @State private var isLoaded = false
    @State private var saving: Task<Void, Never>?

    var body: some View {
        ArchiveRetentionFields(retention: binding, expired: expired, isEnabled: isLoaded)
            .task(id: app.archivedRevision) {
                guard let store = app.store else { return }
                if !isLoaded {
                    retention = await ArchiveRetention.load(from: store)
                    isLoaded = true
                }
                expired = await app.expiredArchives(under: retention)
            }
    }

    private var binding: Binding<ArchiveRetention> {
        Binding(
            get: { retention },
            set: { chosen in
                retention = chosen
                guard let store = app.store else { return }
                saving = Task { [saving] in
                    await saving?.value
                    do {
                        try await chosen.save(to: store)
                    } catch {
                        Log.archive.error("could not save the archive limits: \(error.readableMessage, privacy: .public)")
                        app.notice = Notice(
                            message: "The archive limits were not saved, so the earlier ones still apply. \(error.readableMessage)",
                            tone: .warning
                        )
                        retention = await ArchiveRetention.load(from: store)
                    }
                    expired = await app.expiredArchives(under: retention)
                }
            }
        )
    }
}

struct ArchiveRetentionFields: View {
    @Binding var retention: ArchiveRetention
    let expired: [ArchivedWorkspaceFootprint]?
    let isEnabled: Bool

    var body: some View {
        Section {
            Picker("Delete after", selection: $retention.days) {
                Text("Never").tag(Int?.none)
                ForEach(ArchiveRetention.offeredDays, id: \.self) { days in
                    Text(ArchiveRetention.daysLabel(days)).tag(Int?.some(days))
                }
            }
            .disabled(!isEnabled)

            Picker("Keep at most", selection: $retention.megabytes) {
                Text("No limit").tag(Int?.none)
                ForEach(ArchiveRetention.offeredMegabytes, id: \.self) { megabytes in
                    Text(ArchiveRetention.sizeLabel(megabytes)).tag(Int?.some(megabytes))
                }
            }
            .disabled(!isEnabled)
        } header: {
            Text("Archived workspaces")
        } footer: {
            Text(ArchiveRetention.footer(wouldDelete: expired))
                .settingsFootnote()
        }
    }
}
