import Foundation

public struct HomeRow: Identifiable, Hashable, Sendable {
    public var workspace: Workspace
    public var repo: Repo?
    public var match: String?
    public var footprint: ArchivedWorkspaceFootprint?

    public init(
        workspace: Workspace,
        repo: Repo? = nil,
        match: String? = nil,
        footprint: ArchivedWorkspaceFootprint? = nil
    ) {
        self.workspace = workspace
        self.repo = repo
        self.match = match
        self.footprint = footprint
    }

    public var id: WorkspaceID { workspace.id }

    public var isArchived: Bool { workspace.state != .active }

    public var bytes: Int? { footprint?.totalBytes }
}

public struct HomeGroup: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var rows: [HomeRow]

    public init(id: String, title: String, rows: [HomeRow]) {
        self.id = id
        self.title = title
        self.rows = rows
    }
}

public struct HomeListing: Sendable {
    public var groups: [HomeGroup]
    public var transcripts: [TranscriptWorkspaceMatches]
    public var counts: HomeScopeCounts
    public var isSearching: Bool
    public var shown: Int
    public var considered: Int
    public var archived: Int
    public var shownArchived: Int
    public var shownBytes: Int

    public init(
        groups: [HomeGroup],
        transcripts: [TranscriptWorkspaceMatches] = [],
        counts: HomeScopeCounts = HomeScopeCounts(),
        isSearching: Bool = false,
        shown: Int,
        considered: Int,
        archived: Int,
        shownArchived: Int,
        shownBytes: Int = 0
    ) {
        self.groups = groups
        self.transcripts = transcripts
        self.counts = counts
        self.isSearching = isSearching
        self.shown = shown
        self.considered = considered
        self.archived = archived
        self.shownArchived = shownArchived
        self.shownBytes = shownBytes
    }

    public static let empty = HomeListing(
        groups: [], shown: 0, considered: 0, archived: 0, shownArchived: 0
    )

    public var isEmpty: Bool { groups.isEmpty && transcripts.isEmpty }
}

public struct HomeFilter: Equatable, Sendable {
    public var query = ""
    public var projects: Set<RepoID> = []
    public var scope: HomeScope = .all
    public var order: HomeOrder = .recent

    public init(
        query: String = "",
        projects: Set<RepoID> = [],
        scope: HomeScope = .all,
        order: HomeOrder = .recent
    ) {
        self.query = query
        self.projects = projects
        self.scope = scope
        self.order = order
    }

    public var needle: String { WorkspaceSearch.needle(query) }

    public var isSearching: Bool { !needle.isEmpty }

    public var isNarrowed: Bool {
        isSearching || !projects.isEmpty
    }
}

public enum HomeList {
    public static func build(
        repos: [Repo],
        workspaces: [Workspace],
        archived: [Workspace],
        transcripts: [TranscriptWorkspaceMatches] = [],
        filter: HomeFilter,
        activity: HomeActivity = HomeActivity(),
        footprints: ArchiveCleanup = ArchiveCleanup(footprints: []),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeListing {
        var byID: [RepoID: Repo] = [:]
        byID.reserveCapacity(repos.count)
        for repo in repos { byID[repo.id] = repo }

        var footprintOf: [WorkspaceID: ArchivedWorkspaceFootprint] = [:]
        if filter.scope.showsFootprints {
            footprintOf.reserveCapacity(footprints.footprints.count)
            for footprint in footprints.footprints { footprintOf[footprint.id] = footprint }
        }

        let needle = filter.needle
        let isSearching = filter.isSearching
        var considered = 0
        var counts = HomeScopeCounts()
        var matched: [HomeRow] = []
        matched.reserveCapacity(workspaces.count)

        func consider(_ workspace: Workspace) {
            considered += 1
            if !filter.projects.isEmpty, !filter.projects.contains(workspace.repoID) { return }
            let repo = byID[workspace.repoID]
            let field = WorkspaceSearch.match(workspace: workspace, repo: repo, needle: needle)
            guard !isSearching || field != nil else { return }
            let row = HomeRow(
                workspace: workspace,
                repo: repo,
                match: field == workspace.name ? nil : field,
                footprint: footprintOf[workspace.id]
            )
            matched.append(row)
            if row.isArchived { counts.archived += 1 } else { counts.live += 1 }
            if activity.needsYou(workspace) { counts.needsYou += 1 }
            if activity.isRunning(workspace) { counts.running += 1 }
        }

        for workspace in workspaces { consider(workspace) }
        for workspace in archived { consider(workspace) }
        counts.workspaces = matched.count

        let archivedIDs = Set(archived.map(\.id))
        let hits = transcriptHits(
            transcripts,
            isSearching: isSearching,
            projects: filter.projects,
            workspaces: workspaces,
            archived: archived
        )
        for hit in hits {
            counts.transcripts += hit.total
            counts.transcriptWorkspaces += 1
            if archivedIDs.contains(hit.workspaceID) { counts.archived += hit.total }
        }

        let rows = matched.filter { filter.scope.includes($0, activity: activity) }
        let shownTranscripts = isSearching
            ? hits.filter {
                filter.scope.includesTranscript(isArchived: archivedIDs.contains($0.workspaceID))
            }
            : []

        let order = HomeOrder.applies(scope: filter.scope, searching: isSearching)
            ? filter.order
            : .recent
        let ordered = filter.scope.showsWorkspaces ? sorted(rows, by: order) : []

        let groups: [HomeGroup]
        if isSearching {
            groups = ordered.isEmpty
                ? []
                : [HomeGroup(id: "workspaces", title: "Workspaces", rows: ordered)]
        } else if let heading = order.heading {
            groups = ordered.isEmpty
                ? []
                : [HomeGroup(id: "order-\(order.rawValue)", title: heading, rows: ordered)]
        } else {
            groups = group(ordered, now: now, calendar: calendar)
        }

        return HomeListing(
            groups: groups,
            transcripts: shownTranscripts,
            counts: counts,
            isSearching: isSearching,
            shown: ordered.count,
            considered: considered,
            archived: archived.count,
            shownArchived: ordered.count { $0.isArchived },
            shownBytes: ordered.reduce(0) { $0 + ($1.bytes ?? 0) }
        )
    }

    private static func sorted(_ rows: [HomeRow], by order: HomeOrder) -> [HomeRow] {
        switch order {
        case .recent:
            return rows.sorted { $0.workspace.lastActivityAt > $1.workspace.lastActivityAt }
        case .largest:
            return rows.sorted { first, second in
                let left = first.bytes ?? 0
                let right = second.bytes ?? 0
                if left != right { return left > right }
                return first.id.rawValue < second.id.rawValue
            }
        }
    }

    private static func transcriptHits(
        _ transcripts: [TranscriptWorkspaceMatches],
        isSearching: Bool,
        projects: Set<RepoID>,
        workspaces: [Workspace],
        archived: [Workspace]
    ) -> [TranscriptWorkspaceMatches] {
        guard isSearching, !transcripts.isEmpty else { return [] }
        var repoOf: [WorkspaceID: RepoID] = [:]
        for workspace in workspaces { repoOf[workspace.id] = workspace.repoID }
        for workspace in archived { repoOf[workspace.id] = workspace.repoID }

        return transcripts.filter { result in
            guard let repoID = repoOf[result.workspaceID] else { return false }
            return projects.isEmpty || projects.contains(repoID)
        }
    }

    public static func transcriptHeading(_ results: [TranscriptWorkspaceMatches]) -> String {
        let matches = results.reduce(0) { $0 + $1.total }
        return "In transcripts \u{00B7} \(ArchiveDeletion.count(matches, "match", plural: "matches")) "
            + "in \(ArchiveDeletion.count(results.count, "workspace"))"
    }

    private static func group(
        _ rows: [HomeRow],
        now: Date,
        calendar: Calendar
    ) -> [HomeGroup] {
        var groups: [HomeGroup] = []

        for row in rows {
            let bucket = bucket(for: row.workspace.lastActivityAt, now: now, calendar: calendar)
            if groups.last?.id == bucket.id {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append(HomeGroup(id: bucket.id, title: bucket.title, rows: [row]))
            }
        }

        return groups
    }

    public struct Bucket: Hashable, Sendable {
        public var id: String
        public var title: String

        public init(id: String, title: String) {
            self.id = id
            self.title = title
        }
    }

    public static func bucket(for date: Date, now: Date, calendar: Calendar) -> Bucket {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0

        if days <= 0 { return Bucket(id: "day-0", title: "Today") }
        if days == 1 { return Bucket(id: "day-1", title: "Yesterday") }
        if days < 7 { return Bucket(id: "day-\(days)", title: "\(days) days ago") }

        if days < 28 {
            let weeks = days / 7
            return Bucket(
                id: "week-\(weeks)",
                title: weeks == 1 ? "Last week" : "\(weeks) weeks ago"
            )
        }

        let parts = calendar.dateComponents([.year, .month], from: day)
        let current = calendar.dateComponents([.year, .month], from: today)
        let year = parts.year ?? 0
        let month = parts.month ?? 0

        if year == current.year, month == current.month {
            return Bucket(id: "month-\(year)-\(month)", title: "Earlier this month")
        }

        return Bucket(
            id: "month-\(year)-\(month)",
            title: monthName(of: day, calendar: calendar, includingYear: year != current.year)
        )
    }

    private static func monthName(
        of day: Date, calendar: Calendar, includingYear: Bool
    ) -> String {
        var style = includingYear
            ? Date.FormatStyle.dateTime.month(.wide).year()
            : Date.FormatStyle.dateTime.month(.wide)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        if let locale = calendar.locale { style.locale = locale }
        return day.formatted(style)
    }

    public static func summary(
        listing: HomeListing,
        filter: HomeFilter,
        projects: Int,
        database: DatabaseSize? = nil
    ) -> String {
        guard listing.considered > 0 || listing.archived > 0 else { return "" }

        if listing.isSearching {
            let found = listing.counts.count(of: filter.scope, searching: true)
            let query = filter.query.trimmingCharacters(in: .whitespaces)
            return "\(ArchiveDeletion.count(found, "result")) for \u{201C}\(query)\u{201D}"
        }

        if !filter.projects.isEmpty {
            let total = ArchiveDeletion.count(listing.considered, "workspace")
            return storage(
                on: "Showing \(listing.shown) of \(total)",
                listing: listing, filter: filter, database: database
            )
        }

        let counts = listing.counts
        switch filter.scope {
        case .needsYou:
            return counts.needsYou == 0
                ? "Nothing waiting on you"
                : "\(counts.needsYou) waiting on you"
        case .running:
            return counts.running == 0 ? "Nothing running" : "\(counts.running) running"
        case .archived:
            let head = counts.archived == 0
                ? "Nothing archived"
                : "\(counts.archived) archived\(inProjects(projects))"
            return storage(on: head, listing: listing, filter: filter, database: database)
        case .live:
            let head = counts.live == 0
                ? "Nothing live"
                : "\(counts.live) live\(inProjects(projects))"
            return counts.archived == 0 ? head : "\(head) \u{00B7} \(counts.archived) archived"
        default:
            var text = ArchiveDeletion.count(listing.considered, "workspace") + inProjects(projects)
            if counts.archived > 0 {
                text += " \u{00B7} \(counts.live) live, \(counts.archived) archived"
            }
            return text
        }
    }

    private static func storage(
        on head: String, listing: HomeListing, filter: HomeFilter, database: DatabaseSize?
    ) -> String {
        guard filter.scope.showsFootprints else { return head }
        var text = head
        if listing.shownBytes > 0 {
            text += ", holding \(ArchiveDeletion.bytes(listing.shownBytes))"
        }
        if let database { text += " \u{00B7} " + databaseClause(database) }
        return text
    }

    private static func databaseClause(_ size: DatabaseSize) -> String {
        let total = "Unified Dev\u{2019}s database is \(ArchiveDeletion.bytes(size.totalBytes))"
        guard size.isWorthCompacting else { return total }
        return "\(total), \(ArchiveDeletion.bytes(size.freeBytes)) of it unused"
    }

    private static func inProjects(_ projects: Int) -> String {
        projects > 1 ? " in \(ArchiveDeletion.count(projects, "project"))" : ""
    }
}

public enum HomeAge {
    public static func short(for date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }

        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m" }

        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }

        let days = hours / 24
        if days < 7 { return "\(days)d" }

        let weeks = days / 7
        if weeks < 5 { return "\(weeks)w" }

        let years = days / 365
        if years < 1 { return "\(days / 30)mo" }

        return "\(years)y"
    }

    public static func phrase(for date: Date, now: Date = Date()) -> String {
        let age = short(for: date, now: now)
        return age == "now" ? "just now" : "\(age) ago"
    }
}
