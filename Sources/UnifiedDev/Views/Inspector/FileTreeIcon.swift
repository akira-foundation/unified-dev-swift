import SwiftUI
import Core

struct FileTreeIcon: View {
    let name: String
    let isDirectory: Bool
    let isExpanded: Bool
    @AppStorage(FileIconPack.defaultsKey) private var storedChoice = FileIconPack.defaultChoice.rawValue
    private var choice: FileIconPack { FileIconPack.resolve(storedChoice) }
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasArtwork: Bool {
        FileIconThemeModel.shared.image(
            pack: choice, name: name, isDirectory: isDirectory, expanded: isExpanded,
            isLight: colorScheme == .light
        ) != nil
    }

    var body: some View {
        HStack(spacing: InspectorLayout.gap) {
            if isDirectory {
                Image(systemName: "chevron.right")
                    .font(Typo.micro)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(TreeDisclosureMotion.chevron(reduceMotion: reduceMotion).animation, value: isExpanded)
                    .frame(width: InspectorLayout.glyphWidth, alignment: .leading)
            }
            if let image = FileIconThemeModel.shared.image(
                pack: choice, name: name, isDirectory: isDirectory, expanded: isExpanded, isLight: colorScheme == .light
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: InspectorLayout.glyphWidth, height: InspectorLayout.glyphWidth)
            }
            if !hasArtwork, !isDirectory {
                Image(systemName: "doc")
                    .font(Typo.micro)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .frame(width: InspectorLayout.glyphWidth, alignment: .leading)
            }
        }
        .accessibilityHidden(true)
        .task(id: choice) { FileIconThemeModel.shared.library.prepare(choice) }
    }
}
