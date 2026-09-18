import SwiftUI
import Core

protocol SettingsPage: Hashable, Sendable {
    var title: String { get }
    var systemImage: String { get }
    var tint: Color { get }
    var glyph: Color { get }
}

struct SettingsWindowShell<Page: SettingsPage, Detail: View>: View {
    @Binding var navigation: SettingsNavigation<Page>
    let sections: [SettingsSidebarSection<Page>]
    var searchPrompt: String?
    @ViewBuilder let detail: (Page) -> Detail

    @State private var search = ""

    static var minimumSize: CGSize { CGSize(width: 780, height: 560) }
    static var idealSize: CGSize { CGSize(width: 850, height: 700) }
    static var sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) { (210, 220, 280) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: Self.sidebarWidth.min, ideal: Self.sidebarWidth.ideal, max: Self.sidebarWidth.max
                )
        } detail: {
            detail(navigation.current)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle(navigation.current.title)
        .frame(
            minWidth: Self.minimumSize.width, idealWidth: Self.idealSize.width,
            minHeight: Self.minimumSize.height, idealHeight: Self.idealSize.height
        )
    }

    @ViewBuilder
    private var sidebar: some View {
        let list = List(selection: selection) {
            ForEach(SettingsSidebarSection.matching(sections, query: search, title: \.title)) { section in
                if let title = section.title {
                    Section(title) { rows(section.pages) }
                } else {
                    rows(section.pages)
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { navigation.goBack() } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(!navigation.canGoBack)
                .help("Back")

                Button { navigation.goForward() } label: {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(!navigation.canGoForward)
                .help("Forward")
            }
        }
        if let searchPrompt {
            list.searchable(text: $search, placement: .sidebar, prompt: searchPrompt)
        } else {
            list
        }
    }

    private func rows(_ pages: [Page]) -> some View {
        ForEach(pages, id: \.self) { page in
            SettingsSidebarLabel(title: page.title, systemImage: page.systemImage, tint: page.tint, glyph: page.glyph)
                .tag(page)
        }
    }

    private var selection: Binding<Page?> {
        Binding(get: { navigation.current }, set: { chosen in
            if let chosen { navigation.select(chosen) }
        })
    }
}
