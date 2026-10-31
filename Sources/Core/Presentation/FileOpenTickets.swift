public struct FileOpenTickets: Sendable {
    private var latest: [WorkspaceID: Int] = [:]

    public init() {}

    public mutating func issue(for workspace: WorkspaceID) -> Int {
        let ticket = (latest[workspace] ?? 0) + 1
        latest[workspace] = ticket
        return ticket
    }

    public func isCurrent(_ ticket: Int, for workspace: WorkspaceID) -> Bool {
        latest[workspace] == ticket
    }
}
