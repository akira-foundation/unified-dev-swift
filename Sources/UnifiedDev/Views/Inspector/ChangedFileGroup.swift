import Core

struct ChangedFileGroup: Identifiable {
    var directory: String
    var files: [ChangedFile]

    var id: String { directory }

    static func build(from files: [ChangedFile]) -> [ChangedFileGroup] {
        Dictionary(grouping: files, by: \.directory)
            .map { directory, files in
                let named = files.map { (name: $0.filename, file: $0) }
                return ChangedFileGroup(
                    directory: directory,
                    files: named
                        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                        .map(\.file)
                )
            }
            .sorted { $0.directory.localizedStandardCompare($1.directory) == .orderedAscending }
    }
}
