import Foundation
import Core

struct CenterTab: Identifiable, Hashable, Codable, Sendable {
    typealias Kind = CenterTabKind

    var id: String = newID()
    var workspaceID: WorkspaceID
    var kind: Kind
    var title: String
    var url: String = ""
    var pageTitle: String = ""
    var isNamed: Bool = false
    var directory: String = ""
    var agentSessionID: SessionID?
    var isPinnedToPath: Bool = false
    var path: String = ""
    var showsAllFiles: Bool
    var reviewNavigationRevision: Int = 0
    var runScriptID: String?

    var icon: String {
        switch kind {
        case .terminal: PaneGlyph.terminal
        case .browser: PaneGlyph.browser
        case .review: PaneGlyph.review
        case .notes: PaneGlyph.notes
        }
    }

    static let reviewTitle = "All changes"

    static let notesTitle = "Notes"

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspaceID = try container.decode(WorkspaceID.self, forKey: .workspaceID)
        kind = try container.decode(Kind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        pageTitle = try container.decodeIfPresent(String.self, forKey: .pageTitle) ?? ""
        isNamed = try container.decodeIfPresent(Bool.self, forKey: .isNamed) ?? false
        agentSessionID = try container.decodeIfPresent(SessionID.self, forKey: .agentSessionID)
        directory = try container.decodeIfPresent(String.self, forKey: .directory) ?? ""
        isPinnedToPath = try container.decodeIfPresent(Bool.self, forKey: .isPinnedToPath) ?? false
        runScriptID = try container.decodeIfPresent(String.self, forKey: .runScriptID)
        showsAllFiles = try container.decodeIfPresent(Bool.self, forKey: .showsAllFiles)
            ?? (kind == .review && !isPinnedToPath)
    }

    init(
        id: String = newID(), workspaceID: WorkspaceID, kind: Kind, title: String,
        url: String = "", path: String = "", pageTitle: String = "", isNamed: Bool = false,
        directory: String = "", isPinnedToPath: Bool = false, agentSessionID: SessionID? = nil,
        runScriptID: String? = nil
    ) {
        self.runScriptID = runScriptID
        self.isPinnedToPath = isPinnedToPath
        self.showsAllFiles = kind == .review && !isPinnedToPath
        self.id = id
        self.workspaceID = workspaceID
        self.kind = kind
        self.title = title
        self.url = url
        self.path = path
        self.pageTitle = pageTitle
        self.isNamed = isNamed
        self.directory = directory
        self.agentSessionID = agentSessionID
    }
}
