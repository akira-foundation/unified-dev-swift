import SwiftUI

struct TabItemView: View {
    var title: String
    var icon: TabItemIcon?
    var isActive: Bool
    var isRunning = false
    var surface: TabSurface = TabPane.content.surface
    var isRenaming: Bool
    var editableTitle: String
    var canClose: Bool
    var canRename = true
    var closeTitle: String
    var onSelect: @MainActor () -> Void
    var onStartRename: @MainActor () -> Void
    var onCommitRename: @MainActor (String) -> Void
    var onCancelRename: @MainActor () -> Void
    var onClose: @MainActor () -> Void
    var onSplitRight: (@MainActor () -> Void)?
    var onSplitDown: (@MainActor () -> Void)?
    var onMoveLeft: (@MainActor () -> Void)?
    var onMoveRight: (@MainActor () -> Void)?
    var namespace: Namespace.ID

    @Environment(\.tabItemWidth) private var stripWidth: CGFloat?

    private static let maximumWidth: CGFloat = 200
    private static let renameWidth: CGFloat = 140
    private static let labelHeight: CGFloat = 20
    private static let selectionID = "tabItem.selection"
    private static let capsuleMargin: CGFloat = TabPill.margin

    private static let closeSlop: CGFloat = 1.5

    private static let closeGutter: CGFloat = Metrics.glyph + 6

    @Environment(\.colorSchemeContrast) private var contrast

    @State private var isHovered = false
    @State private var isCloseHovered = false
    @State private var renameText = ""
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if icon != nil || isRunning {
                ZStack {
                    if isRunning {
                        ActivityDot(isActive: true)
                            .accessibilityLabel("Running")
                    }
                    if !isRunning, let icon {
                        TabItemIconView(
                            icon: icon, ink: isActive ? surface.ink : Palette.textSecondary
                        )
                    }
                }
                .frame(width: TabItemIconView.pageSize, height: TabItemIconView.pageSize)
            }

            if isRenaming {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(isActive ? surface.ink : Palette.textPrimary)
                    .focused($isRenameFocused)
                    .frame(width: Self.renameWidth)
                    .onSubmit { onCommitRename(renameText) }
                    .onExitCommand(perform: onCancelRename)
            } else {
                Text(title)
                    .foregroundStyle(isActive ? surface.ink : Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .font(Typo.body)
        .frame(height: Self.labelHeight)
        .padding(.horizontal, TabPill.contentInset + Self.closeGutter)
        .frame(width: stripWidth)
        .frame(maxWidth: stripWidth == nil ? Self.maximumWidth : nil)
        .frame(height: TabPill.barHeight)
        .overlay(alignment: .leading) {
            closeButton.padding(.leading, TabPill.contentInset)
        }
        .background { background.allowsHitTesting(false) }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { if !isCloseHovered { onSelect() } })
        .simultaneousGesture(TapGesture(count: 2).onEnded { if canRename { onStartRename() } })
        .onHover {
            isHovered = $0
            if !$0 { isCloseHovered = false }
        }
        .help(title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .accessibilityActions {
            if canRename { Button("Rename", action: onStartRename) }
            if let onMoveLeft { Button("Move Left", action: onMoveLeft) }
            if let onMoveRight { Button("Move Right", action: onMoveRight) }
        }
        .contextMenu {
            if let onSplitRight, let onSplitDown {
                Button("Open in Split Right", systemImage: PaneSymbol.splitRight, action: onSplitRight)
                Button("Open in Split Down", systemImage: PaneSymbol.splitDown, action: onSplitDown)
                Divider()
            }
            if canRename {
                Button("Rename", systemImage: PaneSymbol.rename, action: onStartRename)
            }
            Button("Close", systemImage: PaneSymbol.closeTab, action: onClose)
                .disabled(!canClose)
        }
        .task(id: isRenaming) { await startEditing() }
    }

    @ViewBuilder
    private var background: some View {
        if isActive {
            shape
                .fill(surface.fill)
                .overlay { shape.strokeBorder(Palette.border.opacity(0.5), lineWidth: Metrics.hairline) }
                .padding(.vertical, Self.capsuleMargin)
                .matchedGeometryEffect(id: Self.selectionID, in: namespace)
        }
        if !isActive, isHovered {
            shape.fill(Palette.hover).padding(.vertical, Self.capsuleMargin)
        }
    }

    private var shape: Capsule { TabPill.shape() }

    private var closeButton: some View {
        Button(action: onClose) {
            Label(closeTitle, systemImage: "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(Typo.caption)
                .imageScale(.small)
                .foregroundStyle(closeInk)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                .padding(Self.closeSlop)
                .contentShape(Rectangle())
                .padding(-Self.closeSlop)
        }
        .buttonStyle(.borderless)
        .onHoverChange { isCloseHovered = $0 }
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!canClose)
        .help(closeTitle)
    }

    private var closeInk: Color {
        guard isVisible else { return .clear }
        return isActive ? surface.inkMuted : Palette.textSecondary
    }

    private var isVisible: Bool {
        canClose && (isHovered || isActive)
    }

    private func startEditing() async {
        guard isRenaming else { return }
        renameText = editableTitle
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }
        isRenameFocused = true
    }
}
