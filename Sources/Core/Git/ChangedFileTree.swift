import Foundation

public struct ChangedFileTreeNode: Identifiable, Sendable, Hashable {
    public enum Content: Sendable, Hashable {
        case folder([ChangedFileTreeNode])
        case file(ChangedFile)
    }

    public var name: String
    public var path: String
    public var content: Content

    public var id: String { path }

    public var isFolder: Bool {
        if case .folder = content { return true }
        return false
    }

    public var children: [ChangedFileTreeNode] {
        if case .folder(let children) = content { return children }
        return []
    }

    public var file: ChangedFile? {
        if case .file(let file) = content { return file }
        return nil
    }
}

public struct ChangedFileTreeRow: Identifiable, Sendable {
    public var node: ChangedFileTreeNode
    public var depth: Int

    public var id: String { node.path }
}

public enum ChangedFileTree {
    private struct Entry {
        var components: ArraySlice<String>
        var file: ChangedFile
    }

    public static func build(from files: [ChangedFile]) -> [ChangedFileTreeNode] {
        let entries = files.compactMap { file -> Entry? in
            let components = file.path
                .components(separatedBy: "/")
                .filter { !$0.isEmpty }
            guard !components.isEmpty else { return nil }
            return Entry(components: components[...], file: file)
        }

        return nodes(from: entries, prefix: "")
    }

    public static func orderedFiles(from files: [ChangedFile]) -> [ChangedFile] {
        rows(from: build(from: files), collapsed: []).compactMap { $0.node.file }
    }

    public static func rows(
        from nodes: [ChangedFileTreeNode],
        collapsed: Set<String>
    ) -> [ChangedFileTreeRow] {
        var result: [ChangedFileTreeRow] = []
        append(nodes, depth: 0, collapsed: collapsed, into: &result)
        return result
    }

    private static func append(
        _ nodes: [ChangedFileTreeNode],
        depth: Int,
        collapsed: Set<String>,
        into result: inout [ChangedFileTreeRow]
    ) {
        for node in nodes {
            result.append(ChangedFileTreeRow(node: node, depth: depth))
            guard node.isFolder, !collapsed.contains(node.path) else { continue }
            append(node.children, depth: depth + 1, collapsed: collapsed, into: &result)
        }
    }

    private static func nodes(from entries: [Entry], prefix: String) -> [ChangedFileTreeNode] {
        var files: [ChangedFileTreeNode] = []
        var folders: [String: [Entry]] = [:]
        var folderOrder: [String] = []

        for entry in entries {
            guard let first = entry.components.first else { continue }
            if entry.components.count == 1 {
                files.append(
                    ChangedFileTreeNode(name: first, path: entry.file.path, content: .file(entry.file))
                )
            } else {
                if folders[first] == nil { folderOrder.append(first) }
                folders[first, default: []].append(
                    Entry(components: entry.components.dropFirst(), file: entry.file)
                )
            }
        }

        let folderNodes = folderOrder.map { name -> ChangedFileTreeNode in
            let path = prefix.isEmpty ? name : prefix + "/" + name
            return collapsing(
                ChangedFileTreeNode(
                    name: name,
                    path: path,
                    content: .folder(nodes(from: folders[name] ?? [], prefix: path))
                )
            )
        }

        return sorted(folderNodes) + sorted(files)
    }

    private static func collapsing(_ node: ChangedFileTreeNode) -> ChangedFileTreeNode {
        guard node.children.count == 1, let only = node.children.first, only.isFolder else {
            return node
        }

        return ChangedFileTreeNode(
            name: node.name + " / " + only.name,
            path: only.path,
            content: only.content
        )
    }

    private static func sorted(_ nodes: [ChangedFileTreeNode]) -> [ChangedFileTreeNode] {
        nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
