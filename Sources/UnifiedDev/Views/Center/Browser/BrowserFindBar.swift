import SwiftUI
import Core

struct BrowserFindBar: View {
    var find: BrowserFind
    var focus: FocusState<Bool>.Binding
    var type: @MainActor (String) -> Void
    var step: @MainActor (BrowserFindCommand) -> Void
    var done: @MainActor () -> Void

    @State private var query = ""

    var body: some View {
        HStack(spacing: Metrics.spacingWide) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: Metrics.glyph)

            field

            if !find.status.isEmpty {
                Text(find.status)
                    .font(Typo.micro)
                    .foregroundStyle(Palette.textTertiary)
            }

            BrowserToolbarButton(
                control: BrowserFindBar.previous(find), action: { step(.previous) }
            )
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .buttonStyle(.glass)

            BrowserToolbarButton(control: BrowserFindBar.next(find), action: { step(.next) })
                .keyboardShortcut("g", modifiers: .command)
                .buttonStyle(.glass)

            Button("Done", action: done)
                .buttonStyle(.glass)
                .font(Typo.caption)
        }
        .padding(.horizontal, Metrics.spacingSmall)
        .frame(height: Metrics.barHeight)
        .background(Palette.surfaceSunken)
        .overlay(alignment: .bottom) { Hairline() }
        .task(id: find.opens) {
            query = find.query
            focus.wrappedValue = true
        }
    }

    private var field: some View {
        TextField("Find on page", text: $query)
            .textFieldStyle(.plain)
            .font(Typo.label)
            .focused(focus)
            .autocorrectionDisabled()
            .frame(maxWidth: 220)
            .onChange(of: query) { type(query) }
            .onSubmit { step(.next) }
            .onExitCommand(perform: done)
    }

    private static func previous(_ find: BrowserFind) -> BrowserToolbar.Control {
        BrowserToolbar.Control(
            symbol: "chevron.up",
            name: "Find Previous",
            help: "Go to the previous match",
            isEnabled: find.canStep
        )
    }

    private static func next(_ find: BrowserFind) -> BrowserToolbar.Control {
        BrowserToolbar.Control(
            symbol: "chevron.down",
            name: "Find Next",
            help: "Go to the next match",
            isEnabled: find.canStep
        )
    }
}
