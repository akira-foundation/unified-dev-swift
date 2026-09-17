import Foundation

public enum PullRequestOffer: Sendable, Hashable {
    case listed(PullRequestListing)
    case typed(PullRequestReference, text: String)
}

public enum WorkspaceSource: Sendable, Hashable, Identifiable {
    case newBranch(from: String)
    case existingBranch(ExistingBranch)
    case pullRequest(PullRequestOffer)

    public var id: String {
        switch self {
        case .newBranch(let ref): "new:\(ref)"
        case .existingBranch(let branch): "branch:\(branch.name)"
        case .pullRequest(.listed(let request)): "pr:\(request.number)"
        case .pullRequest(.typed(let reference, _)): "typed:\(reference.number)"
        }
    }

    public var verb: String {
        switch self {
        case .newBranch: "New branch from"
        case .existingBranch: "Open"
        case .pullRequest: "Review"
        }
    }

    public var name: String {
        switch self {
        case .newBranch(let ref): ref
        case .existingBranch(let branch): branch.name
        case .pullRequest(.listed(let request)):
            request.qualifiedHead.isEmpty ? "#\(request.number) \(request.title)" : request.qualifiedHead
        case .pullRequest(.typed(let reference, _)): "#\(reference.number)"
        }
    }

    public var tab: WorkspaceSourceTab {
        switch self {
        case .newBranch: .newBranch
        case .existingBranch, .pullRequest: .existingBranch
        }
    }

    public var detail: String? {
        guard case .pullRequest(.listed(let request)) = self else { return nil }
        guard !request.qualifiedHead.isEmpty else { return nil }
        return "#\(request.number) \(request.title)"
    }

    public var note: String? {
        switch self {
        case .newBranch:
            return nil
        case .existingBranch(let branch):
            if let holder = branch.inUseBy { return holder.note }
            return branch.isLocal ? nil : "remote"
        case .pullRequest(.listed(let request)):
            let author = request.author.isEmpty ? nil : request.author
            return [request.isDraft ? "draft" : nil, author]
                .compactMap { $0 }
                .joined(separator: ", ")
                .nonEmpty
        case .pullRequest(.typed):
            return "Look it up on GitHub"
        }
    }

    public var heldBy: BranchHolder? {
        guard case .existingBranch(let branch) = self else { return nil }
        return branch.inUseBy
    }

    public var checkout: WorkspaceCheckout? {
        switch self {
        case .newBranch: nil
        case .existingBranch(let branch): .branch(branch)
        case .pullRequest(.listed(let request)): .pullRequest(request)
        case .pullRequest(.typed): nil
        }
    }

    var searchText: String {
        switch self {
        case .newBranch(let ref): ref
        case .existingBranch(let branch): branch.name
        case .pullRequest(.listed(let request)):
            "#\(request.number) \(request.title) \(request.author) \(request.headRefName)"
        case .pullRequest(.typed(let reference, let text)): "#\(reference.number) \(text)"
        }
    }
}

public extension WorkspaceSource {
    static func label(for checkout: WorkspaceCheckout?, baseBranch: String) -> String {
        guard let checkout else { return "from \(baseBranch)" }
        return "on \(checkout.preferredLocalBranch)"
    }
}

public struct WorkspaceSourceOffering: Sendable, Hashable {
    public let pullRequests: [PullRequestListing]
    public let branches: [ExistingBranch]
    public let baseBranches: [String]

    public init(
        pullRequests: [PullRequestListing] = [],
        branches: [ExistingBranch] = [],
        baseBranches: [String] = []
    ) {
        self.pullRequests = pullRequests
        self.branches = branches
        self.baseBranches = baseBranches
    }

    public var openRows: [WorkspaceSource] {
        pullRequests.map { .pullRequest(.listed($0)) } + branches.map { WorkspaceSource.existingBranch($0) }
    }

    public var newBranchRows: [WorkspaceSource] {
        baseBranches.map { .newBranch(from: $0) }
    }

    public nonisolated func search(query: String, limit: Int = 40) -> WorkspaceSourceMatches {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkspaceSourceMatches(
            query: trimmed,
            open: typedRows(for: trimmed) + Self.rank(openRows, query: trimmed, limit: limit),
            new: Self.rank(newBranchRows, query: trimmed, limit: limit)
        )
    }

    public func carryOn(
        from base: String, holders: [String: BranchHolder] = [:]
    ) -> WorkspaceCarryOnOffer? {
        if let request = pullRequests.first(where: { !$0.isCrossRepository && $0.headRefName == base }) {
            return WorkspaceCarryOnOffer(
                source: .pullRequest(.listed(request)), branch: base, holder: holders[base]
            )
        }
        guard let branch = branches.first(where: { $0.name == base }) else { return nil }
        return WorkspaceCarryOnOffer(
            source: .existingBranch(branch), branch: base, holder: branch.inUseBy
        )
    }

    private func typedRows(for query: String) -> [WorkspaceSource] {
        guard let reference = WorkspaceCheckoutPlan.parseReference(query) else { return [] }
        guard !pullRequests.contains(where: { $0.number == reference.number }) else { return [] }
        return [.pullRequest(.typed(reference, text: query))]
    }

    private nonisolated static func rank(
        _ rows: [WorkspaceSource], query: String, limit: Int
    ) -> [WorkspaceSource] {
        guard !query.isEmpty else { return Array(rows.prefix(limit)) }

        var scored: [(row: WorkspaceSource, score: Int, position: Int)] = []
        scored.reserveCapacity(rows.count)
        for (position, row) in rows.enumerated() {
            guard let score = FuzzyMatch.score(row.searchText, query: query) else { continue }
            let nameBonus = FuzzyMatch.score(row.name, query: query) ?? 0
            scored.append((row, score + nameBonus, position))
        }
        scored.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.position < rhs.position
        }
        return scored.prefix(limit).map(\.row)
    }
}

public struct WorkspaceCarryOnOffer: Sendable, Hashable {
    public let source: WorkspaceSource
    public let sentence: String
    public let action: String

    init?(source: WorkspaceSource, branch: String, holder: BranchHolder?) {
        switch holder {
        case .none:
            action = "Open \(branch) instead"
        case .workspace(let name):
            action = "Go to \(name)"
        case .projectCheckout, .otherWorktree:
            return nil
        }
        self.source = source
        sentence = "This cuts a new branch from \(branch)."
    }
}

public enum WorkspaceSourceTab: String, Sendable, Hashable, CaseIterable, Identifiable {
    case newBranch
    case existingBranch

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newBranch: "New branch"
        case .existingBranch: "Existing branch"
        }
    }

    public var explanation: String {
        switch self {
        case .newBranch:
            "Commits land on a new branch, and merge into the branch you pick here."
        case .existingBranch:
            "Commits land on the branch you pick here, and merge when it does."
        }
    }

    public var searchPlaceholder: String {
        switch self {
        case .newBranch: "Search branches to start from"
        case .existingBranch: "Search branches and pull requests, or paste a pull request"
        }
    }

    public func stepped(by step: Int) -> WorkspaceSourceTab {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + step + all.count) % all.count]
    }
}

public struct WorkspaceSourceMatches: Sendable, Hashable {
    public let query: String
    public let open: [WorkspaceSource]
    public let new: [WorkspaceSource]

    public init(query: String = "", open: [WorkspaceSource] = [], new: [WorkspaceSource] = []) {
        self.query = query
        self.open = open
        self.new = new
    }

    public var isEmpty: Bool { open.isEmpty && new.isEmpty }

    public func rows(in tab: WorkspaceSourceTab) -> [WorkspaceSource] {
        switch tab {
        case .newBranch: new
        case .existingBranch: open
        }
    }

    public func isEmpty(in tab: WorkspaceSourceTab) -> Bool { rows(in: tab).isEmpty }

    public func stepped(
        from current: WorkspaceSource?, by step: Int, in tab: WorkspaceSourceTab
    ) -> WorkspaceSource? {
        MenuRows.stepped(from: current, by: step, in: rows(in: tab))
    }

    public func settled(
        after current: WorkspaceSource?, in tab: WorkspaceSourceTab
    ) -> WorkspaceSource? {
        let rows = rows(in: tab)
        guard let current, rows.contains(current) else { return rows.first }
        return current
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
