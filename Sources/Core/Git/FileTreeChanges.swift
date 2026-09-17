public enum FileTreeChanges {
    public static func highlightedPaths(for changedPaths: Set<String>) -> Set<String> {
        var highlighted: Set<String> = []
        for path in changedPaths where !path.isEmpty {
            highlighted.insert(path)
            var parent = path[...]
            while let slash = parent.lastIndex(of: "/") {
                parent = parent[..<slash]
                if !parent.isEmpty { highlighted.insert(String(parent)) }
            }
        }
        return highlighted
    }
}
