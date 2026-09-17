import SwiftUI
import Core

struct BrowserToolbarButton: View {
    var control: BrowserToolbar.Control
    var opticalOffsetY: CGFloat = 0
    var action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Label(control.name, systemImage: control.symbol)
                .labelStyle(.iconOnly)
                .foregroundStyle(control.isEnabled ? Palette.textSecondary : Palette.textDisabled)
                .offset(y: opticalOffsetY)
        }
        .buttonStyle(.glass)
        .disabled(!control.isEnabled)
        .help(control.help)
    }
}

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

    private static let focusRingWidth: CGFloat = 2

    private var isEditing: Bool { addressFocus.wrappedValue }

    private var display: BrowserAddressDisplay { .of(address) }

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: Metrics.spacingWide) {
                navigation.disabled(isReviewing)
                addressField.disabled(isReviewing)
                pageActions
            }
        }
        .padding(.horizontal, Metrics.spacingSmall)
        .frame(height: Metrics.barHeight)
        .background(Palette.surfaceSunken)
    }

    private var navigation: some View {
        actionGroup {
            BrowserToolbarButton(control: toolbar.back, action: goBack)
                .modifier(HistoryMenu(entries: backHistory, go: goToHistory))
            Hairline(axis: .vertical)
            BrowserToolbarButton(control: toolbar.forward, action: goForward)
                .modifier(HistoryMenu(entries: forwardHistory, go: goToHistory))
            Hairline(axis: .vertical)
            pageAction(toolbar.reload, action: reloadOrStop)
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
        .padding(.horizontal, Metrics.spacingWide + Metrics.spacingSmall)
        .frame(height: Metrics.controlHeight)
        .background(alignment: .leading) { load }
        .clipShape(Capsule())
        .glassEffect(.regular, in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                isRingVisible ? Palette.focusRing : Palette.border,
                lineWidth: isRingVisible ? Self.focusRingWidth : Metrics.outline
            )
        }
    }

    private var pageActions: some View {
        HStack(spacing: Metrics.spacing) {
            actionGroup {
                BrowserViewportButton(viewport: viewport)
                    .frame(width: pageActionWidth, height: Metrics.controlHeight)
                Hairline(axis: .vertical)
                pageAction(BrowserToolbar.Control(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    name: "Full size",
                    help: "Restore the page to the full browser pane",
                    isEnabled: viewport.wrappedValue.isEnabled
                )) {
                    viewport.wrappedValue.isEnabled = false
                }
            }
            .disabled(isReviewing)
            actionGroup {
                pageAction(toolbar.screenshot, action: capture)
                Hairline(axis: .vertical)
                Button(action: captureRegion) {
                    Label(isReviewing ? "Done" : "Comment", systemImage: isReviewing ? "checkmark" : "text.bubble")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(commentInk)
                }
                .buttonStyle(.glass)
                .frame(width: pageActionWidth, height: Metrics.controlHeight)
                .disabled(!isCommentEnabled)
                .help(isReviewing ? "Finish reviewing this page" : "Drag over part of this page to leave a comment")
            }
            actionGroup {
                BrowserShareButton(
                    control: toolbar.share,
                    shareable: toolbar.shareable,
                    opticalOffsetY: -0.5
                )
                .frame(width: pageActionWidth, height: Metrics.controlHeight)
            }
        }
    }

    private var isCommentEnabled: Bool {
        !isSavingReview && (isReviewing || toolbar.regionCapture.isEnabled)
    }

    private var commentInk: Color {
        guard isCommentEnabled else { return Palette.textDisabled }
        return isReviewing ? Palette.accent : Palette.textSecondary
    }

    private func actionGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0, content: content)
            .frame(height: Metrics.controlHeight)
            .clipShape(Capsule())
            .glassEffect(.regular, in: Capsule())
            .overlay { Capsule().strokeBorder(Palette.border, lineWidth: Metrics.outline) }
    }

    private func pageAction(
        _ control: BrowserToolbar.Control, action: @escaping @MainActor () -> Void
    ) -> some View {
        BrowserToolbarButton(control: control, action: action)
            .frame(width: pageActionWidth, height: Metrics.controlHeight)
    }

    private var pageActionWidth: CGFloat { Metrics.controlHeight + Metrics.spacingSmall }

    @ViewBuilder private var load: some View {
        if let progress = toolbar.progress {
            GeometryReader { proxy in
                Palette.selected.frame(width: proxy.size.width * progress)
            }
            .animation(Motion.pane, value: progress)
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
