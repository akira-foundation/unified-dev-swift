import SwiftUI
import Core

struct BrowserToolbarGallery: View {
    private static let pane: CGFloat = 520

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            row(
                "A pane nobody has pointed anywhere",
                "Split open on nothing. Both arrows dead, nothing to reload and nothing to share.",
                BrowserToolbar()
            )
            row(
                "The dev server, just opened",
                "Somewhere to be, so Reload and Share come alive. Still no history either way.",
                BrowserToolbar(page: page("http://localhost:3100/", "Unified Dev"))
            )
            row(
                "Four links deep",
                "Back can be pressed, and a right click on it offers the pages it would walk past.",
                BrowserToolbar(page: page("http://localhost:3100/settings", "Settings"), canGoBack: true)
            )
            row(
                "Gone back, so there is a page ahead as well",
                "The one state that puts both arrows in the same bar.",
                BrowserToolbar(
                    page: page("http://localhost:3100/", "Unified Dev"),
                    canGoBack: true,
                    canGoForward: true
                )
            )
            row(
                "Loading",
                "Reload becomes Stop in place, and the accent line along the foot of the address is how far it has got.",
                BrowserToolbar(
                    page: page("https://akira-io.com/docs", "Docs"),
                    canGoBack: true,
                    isLoading: true,
                    loadProgress: 0.45
                )
            )
            row(
                "A URL longer than the pane",
                "Cut at the tail, so the host is the part that always survives.",
                BrowserToolbar(
                    page: page(
                        "https://github.com/akira-io/laravel-medialibrary/pull/3812/files"
                            + "#diff-a7b3f2c9?utm_source=unifieddev&expand=1",
                        "Files changed"
                    ),
                    canGoBack: true
                )
            )
            row(
                "A screenshot on its way to the composer",
                "The camera goes quiet rather than attaching the same page twice.",
                BrowserToolbar(page: page("http://localhost:3100/", "Unified Dev"), isCapturing: true)
            )
            row(
                "Reviewing the page",
                "Comment turns into Done, lit in the system accent, while the arrows and the address wait.",
                BrowserToolbar(page: page("http://localhost:3100/", "Unified Dev"), isCapturing: true),
                isReviewing: true
            )
            row(
                "At a phone's size",
                "The viewport glyph is lit and Full size comes alive beside it.",
                BrowserToolbar(page: page("http://localhost:3100/", "Unified Dev")),
                isSized: true
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func page(_ address: String, _ title: String) -> BrowserTabTitle.BrowserPage {
        BrowserTabTitle.BrowserPage(address: address, title: title)
    }

    private func row(
        _ title: String, _ note: String, _ toolbar: BrowserToolbar,
        isReviewing: Bool = false, isSized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            Text(note)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            BarRow(toolbar: toolbar, isReviewing: isReviewing, isSized: isSized)
                .frame(width: Self.pane)
        }
    }

    private struct BarRow: View {
        var toolbar: BrowserToolbar
        var isReviewing: Bool
        var isSized: Bool

        @State private var address = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            BrowserToolbarView(
                toolbar: toolbar,
                address: $address,
                addressFocus: $isFocused,
                isRingVisible: false,
                backHistory: toolbar.canGoBack ? Self.history : [],
                forwardHistory: toolbar.canGoForward ? BrowserToolbar.forwardMenu(Self.pages) : [],
                isReviewing: isReviewing,
                viewport: .constant(viewport)
            )
            .task { address = toolbar.page.address }
        }

        private var viewport: BrowserViewport {
            var viewport = BrowserViewport()
            viewport.isEnabled = isSized
            return viewport
        }

        private static let pages = [
            BrowserTabTitle.BrowserPage(address: "http://localhost:3100/", title: "Unified Dev"),
            BrowserTabTitle.BrowserPage(address: "http://localhost:3100/workspaces", title: "Workspaces"),
        ]

        private static let history = BrowserToolbar.backMenu(pages)
    }
}

extension Gallery {
    static let browserToolbar = Gallery(
        name: "browser-toolbar",
        title: "Browser toolbar",
        size: CGSize(width: 570, height: 1000),
        needsFocus: false,
        view: { _ in AnyView(BrowserToolbarGallery()) }
    )
}
