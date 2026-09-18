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
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
