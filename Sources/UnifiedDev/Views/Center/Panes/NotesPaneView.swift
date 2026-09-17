import SwiftUI
import Core

struct NotesPaneView: View {
    @Bindable var model: WorkspaceModel

    @State private var text = ""
    @State private var saved = ""
    @State private var hasLoaded = false
    @State private var couldNotLoad = false
    @State private var couldNotSave = false
    @State private var saveTask: Task<Void, Never>?
    @FocusState private var isEditing: Bool

    var body: some View {
        NotesPage(
            text: $text,
            isEditing: $isEditing,
            workspaceID: model.workspace.id,
            workspaceName: model.workspace.name,
            hasLoaded: hasLoaded,
            couldNotLoad: couldNotLoad,
            couldNotSave: couldNotSave,
            hasChanges: WorkspaceNote.needsSave(stored: saved, typed: text),
            onRetryLoad: { Task { await load() } },
            onRetrySave: saveNow
        )
        .onChange(of: text) { _, _ in scheduleSave() }
        .task { await load() }
        .onChange(of: isEditing) { _, editing in if !editing { saveNow() } }
        .focusedValue(\.isTypingProse, isEditing)
        .onDisappear(perform: saveNow)
    }

    private func load() async {
        guard !hasLoaded, let store = model.store else { return }
        do {
            let stored = try await store.note(workspaceID: model.workspace.id)?.body ?? ""
            text = stored
            saved = stored
            couldNotLoad = false
            hasLoaded = true
        } catch {
            couldNotLoad = true
        }
    }

    private func scheduleSave() {
        guard hasLoaded else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: WorkspaceNote.autosaveDelay)
            guard !Task.isCancelled else { return }
            await write()
        }
    }

    private func saveNow() {
        saveTask?.cancel()
        guard hasLoaded, WorkspaceNote.needsSave(stored: saved, typed: text) else { return }
        guard let store = model.store else { return }
        let workspaceID = model.workspace.id
        let body = text
        Task { @MainActor in
            do {
                try await store.saveNote(workspaceID: workspaceID, body: body)
                saved = body
                couldNotSave = false
            } catch {
                couldNotSave = true
            }
        }
    }

    private func write() async {
        guard let store = model.store else { return }
        guard WorkspaceNote.needsSave(stored: saved, typed: text) else { return }
        let body = text
        do {
            try await store.saveNote(workspaceID: model.workspace.id, body: body)
            saved = body
            couldNotSave = false
        } catch {
            couldNotSave = true
        }
    }
}
