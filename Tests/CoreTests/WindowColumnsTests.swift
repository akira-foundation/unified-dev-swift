import CoreGraphics
import Foundation
import Testing
@testable import Core

@Suite("Window columns")
struct WindowColumnsTests {
    private static let widths = WindowWidths(
        sidebar: 420, sidebarMinimum: 200, detail: 560, inspector: 320, divider: 1
    )

    private static let wide: CGFloat = 1_800

    private static let narrow: CGFloat = 700

    private func columns(
        _ selection: SidebarSelection,
        hasInspectorSubject: Bool = false,
        wantsInspector: Bool = false,
        hidesSidebar: Bool = false,
        availableWidth: CGFloat = WindowColumnsTests.wide
    ) -> WindowColumns {
        WindowColumns.resolve(
            selection: selection,
            hasInspectorSubject: hasInspectorSubject,
            wantsInspector: wantsInspector,
            hidesSidebar: hidesSidebar,
            widths: Self.widths,
            availableWidth: availableWidth
        )
    }

    private static let everySelection: [SidebarSelection] = [
        .home,
        .ask,
        .workspace(WorkspaceID("live")),
        .archived(WorkspaceID("gone")),
        .subagent(WorkspaceID("live"), SubagentID("sub")),
        .subagentCall(WorkspaceID("live"), toolUseID: "toolu_1"),
        .crew(WorkspaceID("live"), SessionID("session")),
        .draft(RepoID("repo")),
    ]

    @Test("an archived selection keeps the sidebar and the centre column")
    func archivedKeepsItsColumns() {
        let resolved = columns(.archived(WorkspaceID("gone")))
        #expect(resolved.drawsSidebar)
        #expect(resolved.reach == .all)
        #expect(!resolved.drawsInspector)
    }

    @Test("an archived selection in a window too narrow for the sidebar still draws the centre column")
    func archivedInANarrowWindow() {
        let resolved = columns(.archived(WorkspaceID("gone")), availableWidth: Self.narrow)
        #expect(!resolved.drawsSidebar)
        #expect(resolved.reach == .withoutSidebar)
        #expect(!resolved.drawsInspector)
    }

    @Test("no selection and no width leaves the window showing the centre column")
    func theCentreColumnIsNeverTheOneThatGoes() {
        for selection in Self.everySelection {
            for hasSubject in [true, false] {
                for wants in [true, false] {
                    for hides in [true, false] {
                        for width in [Self.wide, Self.narrow, 0 as CGFloat] {
                            let resolved = columns(
                                selection,
                                hasInspectorSubject: hasSubject,
                                wantsInspector: wants,
                                hidesSidebar: hides,
                                availableWidth: width
                            )
                            #expect(resolved.reach == (resolved.drawsSidebar ? .all : .withoutSidebar))
                        }
                    }
                }
            }
        }
    }

    @Test("the inspector belongs to a live workspace and to nothing else")
    func theInspectorFollowsTheWorkspace() {
        #expect(columns(.workspace(WorkspaceID("live")), hasInspectorSubject: true).drawsInspector)
        #expect(columns(.crew(WorkspaceID("live"), SessionID("s")), hasInspectorSubject: true).drawsInspector)
        #expect(!columns(.workspace(WorkspaceID("live")), hasInspectorSubject: false).drawsInspector)
        #expect(!columns(.archived(WorkspaceID("gone")), hasInspectorSubject: true).drawsInspector)
        #expect(!columns(.home, hasInspectorSubject: true).drawsInspector)
        #expect(!columns(.ask, hasInspectorSubject: true).drawsInspector)
        #expect(!columns(.draft(RepoID("repo")), hasInspectorSubject: true).drawsInspector)
    }

    @Test("hiding the sidebar is the owner's decision and does not fold the centre column away")
    func hidingTheSidebar() {
        let hidden = columns(.workspace(WorkspaceID("live")), hasInspectorSubject: true, hidesSidebar: true)
        #expect(!hidden.drawsSidebar)
        #expect(hidden.reach == .withoutSidebar)
        #expect(hidden.drawsInspector)
    }

    @Test("the sidebar ceiling is the room the window has for it")
    func theSidebarCeiling() {
        #expect(columns(.home).sidebarCeiling == Self.widths.sidebar)
        let shared = columns(
            .workspace(WorkspaceID("live")), hasInspectorSubject: true, wantsInspector: true,
            availableWidth: 1_200
        )
        #expect(shared.sidebarCeiling == 318)
        #expect(columns(.home, availableWidth: Self.narrow).sidebarCeiling == Self.widths.sidebarMinimum)
    }

    @Test("an archived selection is given the room a workspace would have asked the inspector for")
    func archivedDoesNotReserveInspectorRoom() {
        let archived = columns(
            .archived(WorkspaceID("gone")), hasInspectorSubject: true, wantsInspector: true,
            availableWidth: 1_000
        )
        let live = columns(
            .workspace(WorkspaceID("live")), hasInspectorSubject: true, wantsInspector: true,
            availableWidth: 1_000
        )
        #expect(archived.drawsSidebar)
        #expect(!live.drawsSidebar)
    }
}
