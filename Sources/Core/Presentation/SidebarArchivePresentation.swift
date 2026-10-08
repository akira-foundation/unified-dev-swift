import Foundation

public struct SidebarArchivePresentation: Sendable {
    public enum Source: Sendable { case button, menu, row }

    public private(set) var workspaceID: WorkspaceID?
    public private(set) var source = Source.row
    public private(set) var request: ArchiveRequest?
    public private(set) var isRequesting = false
    private var generation = UUID()
    private var isVisible = false
    private var isReturningAfterArchive = false

    public init() {}

    public mutating func begin(workspaceID: WorkspaceID, source: Source) -> UUID {
        generation = UUID()
        self.workspaceID = workspaceID
        self.source = source
        request = nil
        isRequesting = true
        isVisible = true
        isReturningAfterArchive = false
        return generation
    }

    public mutating func apply(
        _ update: ArchiveConfirmationFlow.Update, generation: UUID
    ) {
        guard self.generation == generation, workspaceID == update.workspaceID,
              isVisible || isReturningAfterArchive else { return }
        request = ArchiveConfirmationFlow.shows(update, while: request, replacesInPlace: true)
    }

    public mutating func finish(generation: UUID) {
        guard self.generation == generation else { return }
        isRequesting = false
    }

    public mutating func rowAppeared(_ id: WorkspaceID) {
        guard workspaceID == id else { return }
        isVisible = true
        isReturningAfterArchive = false
    }

    public mutating func rowDisappeared(_ id: WorkspaceID, isArchiving: Bool) {
        guard workspaceID == id else { return }
        isVisible = false
        isReturningAfterArchive = isArchiving
        if !isArchiving { cancel() }
    }

    public mutating func dismissRequest() {
        guard request != nil else { return }
        cancel()
    }

    public mutating func cancel() {
        generation = UUID()
        request = nil
        isRequesting = false
        isReturningAfterArchive = false
    }
}
