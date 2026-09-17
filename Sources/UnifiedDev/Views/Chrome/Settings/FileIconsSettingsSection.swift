import SwiftUI
import Core

struct FileIconsSettingsSection: View {
    @AppStorage(FileIconPack.defaultsKey) private var storedChoice = FileIconPack.defaultChoice.rawValue
    private var choice: FileIconPack { FileIconPack.resolve(storedChoice) }
    private var library: FileIconPackLibrary { FileIconThemeModel.shared.library }

    private enum PackState {
        case installing
        case failed(String)
        case installed
        case absent
    }

    private var state: PackState {
        if library.loading.contains(choice) { return .installing }
        if let error = library.errors[choice] { return .failed(error) }
        if library.packs[choice] != nil { return .installed }
        return .absent
    }

    var body: some View {
        Section("All files icons") {
            Picker("Icon pack", selection: selection) {
                ForEach(FileIconPack.allCases) { pack in
                    Text(pack.title).tag(pack.rawValue)
                }
            }
            Text("vscode-icons is selected by default. Each pack downloads once when selected, then works offline.")
                .settingsFootnote()
            switch state {
            case .installing:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Installing \(choice.title)…").foregroundStyle(.secondary)
                }
            case let .failed(error):
                Text("Could not install \(choice.title): \(error)")
                    .foregroundStyle(.red)
                    .settingsFootnote()
                Button("Retry installation") { library.prepare(choice, retry: true) }
            case .installed:
                Text("Installed").settingsFootnote()
            case .absent:
                EmptyView()
            }
            if let download = choice.download {
                Link("\(choice.title) · Icon credits and licences", destination: download.marketplaceURL)
                    .settingsFootnote()
            }
        }
        .task(id: choice) { library.prepare(choice) }
    }

    private var selection: Binding<String> {
        Binding(get: { choice.rawValue }, set: { storedChoice = $0 })
    }
}
