import SwiftUI
import Core

struct CommandMenuGallery: View {
    var app: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            column("On the pane's own ground", ground: Palette.windowBackground)
            column("On nothing", ground: Color.clear)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ title: String, ground: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Typo.label).foregroundStyle(Palette.textSecondary)

            SlashCommandMenu(
                matches: Self.matches,
                query: "re",
                isLoaded: true,
                selectedIndex: 1,
                maxHeight: 320,
                availableWidth: 460,
                onPick: { _ in }
            )
            .padding(20)
            .background(ground)
        }
    }

    private static let matches: [SlashCommandMatch] = [
        match("review", "Review a pull request", kind: .command),
        match("code-review", "Review the changes since a fixed point", kind: .command),
        match("release-review", "Use when a release is about to be cut", kind: .skill),
    ]

    private static func match(
        _ name: String, _ detail: String, kind: SlashCommand.Kind
    ) -> SlashCommandMatch {
        SlashCommandMatch(
            command: SlashCommand(name: name, detail: detail, kind: kind, scope: .user),
            score: 0,
            highlights: []
        )
    }
}

extension Gallery {
    static let commandMenu = Gallery(
        name: "command-menu",
        title: "Command menu",
        size: CGSize(width: 1120, height: 560),
        needsFocus: false,
        view: { app in AnyView(CommandMenuGallery(app: app)) }
    )
}
