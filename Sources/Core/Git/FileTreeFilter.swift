import Foundation

public enum FileTreeFilter {
    public struct Outcome: Equatable, Sendable {
        public var children: [String: [FileTreeNode]]
        public var open: Set<String>

        public init(children: [String: [FileTreeNode]], open: Set<String>) {
            self.children = children
            self.open = open
        }

        public var isEmpty: Bool { children[""]?.isEmpty ?? true }
    }

    public static func apply(
        to children: [String: [FileTreeNode]], needle: String
    ) -> Outcome? {
        guard !needle.isEmpty else { return nil }

        var outcome = Outcome(children: [:], open: [])
        prune(directory: "", of: children, needle: needle, into: &outcome)
        return outcome
    }

    @discardableResult
    private static func prune(
        directory: String,
        of children: [String: [FileTreeNode]],
        needle: String,
        into outcome: inout Outcome
    ) -> Bool {
        var survivors: [FileTreeNode] = []

        for node in children[directory] ?? [] {
            guard node.isDirectory else {
                if matches(node, needle: needle) { survivors.append(node) }
                continue
            }

            if matches(node, needle: needle) {
                copy(subtreeOf: node.path, of: children, into: &outcome)
                outcome.open.insert(node.path)
                survivors.append(node)
                continue
            }

            if prune(directory: node.path, of: children, needle: needle, into: &outcome) {
                outcome.open.insert(node.path)
                survivors.append(node)
            }
        }

        if !survivors.isEmpty || directory.isEmpty { outcome.children[directory] = survivors }
        return !survivors.isEmpty
    }

    private static func copy(
        subtreeOf directory: String,
        of children: [String: [FileTreeNode]],
        into outcome: inout Outcome
    ) {
        guard let nodes = children[directory] else { return }
        outcome.children[directory] = nodes
        for node in nodes where node.isDirectory {
            copy(subtreeOf: node.path, of: children, into: &outcome)
        }
    }

    private static func matches(_ node: FileTreeNode, needle: String) -> Bool {
        FileNeedle.matches(needle.contains("/") ? node.path : node.name, needle: needle)
    }
}
