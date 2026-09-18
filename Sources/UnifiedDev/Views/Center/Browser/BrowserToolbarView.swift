import SwiftUI
import Core

struct BrowserToolbarView: View {
    var toolbar: BrowserToolbar
    @Binding var address: String
    var addressFocus: FocusState<Bool>.Binding
    var isRingVisible: Bool
    var backHistory: [BrowserToolbar.HistoryEntry] = []
    var forwardHistory: [BrowserToolbar.HistoryEntry] = []

    var goBack: @MainActor () -> Void = {}
    var goForward: @MainActor () -> Void = {}
    var goToHistory: @MainActor (Int) -> Void = { _ in }
    var reloadOrStop: @MainActor () -> Void = {}
    var capture: @MainActor () -> Void = {}
    var captureRegion: @MainActor () -> Void = {}
    var isReviewing = false
    var isSavingReview = false
    var viewport: Binding<BrowserViewport> = .constant(BrowserViewport())
    var submit: @MainActor () -> Void = {}

    @Namespace private var glass

    private enum Pill: Hashable, Sendable {
        case navigation
        case actions
    }

    private static let height: CGFloat = 40
    private static let pillHeight: CGFloat = 30
    private static let pillSpacing: CGFloat = 10
    private static let progressHeight: CGFloat = 2
    private static let focusRingWidth: CGFloat = 2

    private var isEditing: Bool { addressFocus.wrappedValue }

    private var display: BrowserAddressDisplay { .of(address) }

    var body: some View {
        GlassEffectContainer(spacing: Self.pillSpacing) {
            HStack(spacing: Self.pillSpacing) {
                navigation.disabled(isReviewing)
                addressField.disabled(isReviewing)
                pageActions
            }
        }
        .padding(.horizontal, Metrics.spacingWide)
        .frame(height: Self.height)
    }

    private var navigation: some View {
        pill(.navigation) {
            BrowserToolbarButton(control: toolbar.back, action: goBack)
                .modifier(HistoryMenu(entries: backHistory, go: goToHistory))
            BrowserToolbarButton(control: toolbar.forward, action: goForward)
                .modifier(HistoryMenu(entries: forwardHistory, go: goToHistory))
            BrowserToolbarButton(control: toolbar.reload, action: reloadOrStop)
        }
    }

    private var addressField: some View {
        HStack(spacing: Metrics.spacingSmall) {
            if !isEditing, let symbol = display.security.symbol {
                Image(systemName: symbol)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiaryOnGlass)
                    .help(display.security.help ?? "")
                    .accessibilityLabel(display.security.help ?? "")
            }
            field
        }
        .padding(.horizontal, Metrics.gutter)
        .frame(height: Self.pillHeight)
        .overlay(alignment: .bottomLeading) { load }
        .clipShape(Capsule())
        .glassEffect(.regular, in: Capsule())
        .overlay {
            if isRingVisible {
                Capsule().strokeBorder(Palette.focusRing, lineWidth: Self.focusRingWidth)
            }
        }
    }

    private var pageActions: some View {
        pill(.actions) {
            BrowserViewportButton(viewport: viewport)
                .disabled(isReviewing)
            BrowserToolbarButton(control: BrowserToolbar.fullSize(viewport.wrappedValue)) {
                viewport.wrappedValue.isEnabled = false
            }
            .disabled(isReviewing)
            BrowserToolbarButton(control: toolbar.screenshot, action: capture)
            BrowserToolbarButton(
                control: toolbar.comment(isReviewing: isReviewing, isSaving: isSavingReview),
                action: captureRegion
            )
            BrowserShareButton(control: toolbar.share, shareable: toolbar.shareable, opticalOffsetY: -0.5)
        }
    }

    private func pill<Content: View>(_ id: Pill, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            ForEach(subviews: content()) { piece in
                piece.glassEffectUnion(id: id, namespace: glass)
            }
        }
    }

    @ViewBuilder private var load: some View {
        if let progress = toolbar.progress {
            GeometryReader { proxy in
                Palette.accent.frame(width: proxy.size.width * progress)
            }
            .frame(height: Self.progressHeight)
            .animation(Motion.pane, value: progress)
            .accessibilityHidden(true)
        }
    }

    private var field: some View {
        ZStack(alignment: .leading) {
            TextField("Address", text: $address)
                .textFieldStyle(.plain)
                .font(Typo.label)
                .focused(addressFocus)
                .autocorrectionDisabled()
                .foregroundStyle(isEditing ? Palette.textPrimary : .clear)
                .onSubmit(submit)

            if !isEditing, !display.isEmpty {
                addressLabel.allowsHitTesting(false)
            }
        }
    }

    private func tinted(_ string: String, _ colour: Color) -> Text {
        Text(string).foregroundStyle(colour)
    }

    private var dim: Color { Palette.textTertiaryOnGlass }

    private var addressLabel: some View {
        Text("\(tinted(display.leading, dim))\(tinted(display.host, Palette.textPrimary))\(tinted(display.trailing, dim))")
            .lineLimit(1)
            .truncationMode(.tail)
            .font(Typo.label)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryMenu: ViewModifier {
    var entries: [BrowserToolbar.HistoryEntry]
    var go: @MainActor (Int) -> Void

    func body(content: Content) -> some View {
        if entries.isEmpty {
            content
        } else {
            content.contextMenu {
                ForEach(entries) { entry in
                    Button(entry.name) { go(entry.id) }
                }
            }
        }
    }
}
