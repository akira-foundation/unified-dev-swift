import Testing
@testable import Core

@Suite("File open tickets")
struct FileOpenTicketsTests {
    private let gulf = WorkspaceID("gulf")
    private let bay = WorkspaceID("bay")

    @Test("the last ticket issued is the only current one")
    func lastWins() {
        var tickets = FileOpenTickets()
        let first = tickets.issue(for: gulf)
        let second = tickets.issue(for: gulf)
        #expect(!tickets.isCurrent(first, for: gulf))
        #expect(tickets.isCurrent(second, for: gulf))
    }

    @Test("an open in another workspace does not make this one stale")
    func perWorkspace() {
        var tickets = FileOpenTickets()
        let here = tickets.issue(for: gulf)
        let there = tickets.issue(for: bay)
        #expect(tickets.isCurrent(here, for: gulf))
        #expect(tickets.isCurrent(there, for: bay))
    }

    @Test("a ticket never issued for a workspace is not current there")
    func neverIssued() {
        var tickets = FileOpenTickets()
        let here = tickets.issue(for: gulf)
        #expect(!tickets.isCurrent(here, for: bay))
    }
}
