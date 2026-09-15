import SwiftUI

/// The chrome every tab in Unified Dev wears, whatever it holds and whichever strip it is in.
///
/// A conversation, a shell, a web page, a setup log and a run script have nothing in common except
/// that the user switches between them, so the switching is the only part they share. Height,
/// hover, the rename editor and the close button live here rather than in five places that would
/// drift apart the first time one of them was restyled. The bottom panel used to draw its own,
/// which is how it ended up with square corners, a different rename field and no outline while the
/// centre column was being measured against Safari.
///
/// The tab owns its own hover and its own rename field. The strip only says which tab is being
/// renamed, so two tabs can never both think they hold the editor.
struct TabItemView: View {
    var title: String
    /// Every kind carries one, including a chat: a strip with a glyph on two tabs of three reads
    /// as a row that has lost an icon. Still optional, because the bottom panel's setup log and
    /// run scripts are named after the script and have nothing to add.
    ///
    /// A `TabItemIcon` rather than a symbol name, because a browser tab wears the page's own
    /// favicon and that is a picture rather than a glyph. See `TabItemIcon`.
    var icon: TabItemIcon?
    var isActive: Bool
    var isRunning = false
    /// The ground of the pane this tab opens and the ink that reads on it, worn while the tab is
    /// the selected one. `TabPane.content.surface` for the centre column, `.sunken` for the bottom
    /// panel, and the user's own Ghostty colours for a terminal running their theme.
    var surface: TabSurface = TabPane.content.surface
    var isRenaming: Bool
    /// What the rename field opens with. Kept apart from `title` because a session that has not
    /// been named yet shows "Untitled", and putting that word into the editor hands the user a
    /// name they never chose.
    var editableTitle: String
    var canClose: Bool
    /// Whether double clicking the tab opens a name field. A review is named after the file it is
    /// showing, so a name of the reader's own would be overwritten the moment they clicked
    /// another one.
    var canRename = true
    /// What the close button and its context menu item call this tab, for VoiceOver and tooltips.
    var closeTitle: String
    var onSelect: @MainActor () -> Void
    var onStartRename: @MainActor () -> Void
    var onCommitRename: @MainActor (String) -> Void
    var onCancelRename: @MainActor () -> Void
    var onClose: @MainActor () -> Void
    /// Opening the tab beside the pane it is already in, for anyone who would rather pick a menu
    /// item than drag the tab into the half of the pane they want it in.
    ///
    /// Absent in the bottom panel, which is one pane and cannot be split from its strip: a
    /// terminal there splits inside its own view. The menu items go with them rather than being
    /// shown greyed, because a permanently disabled item is a worse answer than no item.
    var onSplitRight: (@MainActor () -> Void)?
    var onSplitDown: (@MainActor () -> Void)?
    /// The strip's namespace, so the selected tab's fill is one view that moves rather than one
    /// that is destroyed here and built again over there. Without it the highlight blinks from
    /// tab to tab, and a highlight that blinks is the single clearest tell that a tab strip was
    /// drawn rather than grown.
    var namespace: Namespace.ID

    /// The share of the strip this tab was given, when the strip divides itself between its tabs
    /// the way Safari's does. Nil leaves the tab as wide as what it says.
    @Environment(\.tabItemWidth) private var stripWidth: CGFloat?

    /// A tab stops growing here so one long title cannot push every other tab out of the strip.
    /// Only read by a strip that does not divide itself between its tabs; one that does hands
    /// every tab the same width and caps it at `TabPill.maximumWidth`.
    private static let maximumWidth: CGFloat = 200
    /// Wide enough for the titles tabs actually get, and the same width whichever tab is being
    /// renamed, so the strip does not jump as the editor opens.
    private static let renameWidth: CGFloat = 140
    /// The row every tab centres in the strip. Fixed rather than intrinsic because a rename field
    /// is a point or two taller than a label, and a tab that grew as its editor opened put its
    /// text on a different line from the tabs beside it.
    private static let labelHeight: CGFloat = 20
    /// One highlight for the whole strip, so `matchedGeometryEffect` has something to match on.
    private static let selectionID = "tabItem.selection"
    /// How far the selected tab's own capsule sits in from the top and bottom of the row, so it
    /// reads as a pill floating on `TabStrip`'s track rather than as a lid fused to the pane
    /// below it. See macOS 26 Finder, quoted in `docs/superpowers/specs/2026-09-14-apple-ui-rules.md`.
    private static let capsuleMargin: CGFloat = TabPill.margin

    /// How much wider the close cross's hit box is than the cross, on every side.
    ///
    /// `Metrics.glyph` is 13 and its own doc calls it "the box a sidebar row's state glyph sits
    /// in, matching the cap height of the text beside it", which is a metric for lining marks up
    /// down a column and not one for aiming at. Safari's cross is a 16 point target. Taken as
    /// padding under a `contentShape` and then taken straight back off, so the target grows and
    /// the strip's layout does not: every tab would otherwise be three points wider, and at the
    /// 200 point ceiling three points come off the title instead.
    private static let closeSlop: CGFloat = 1.5

    /// The gutter the cross stands in, kept clear at both ends of a tab. `Metrics.glyph` is the
    /// cross itself; the extra points are the air between it and the glyph beside it.
    private static let closeGutter: CGFloat = Metrics.glyph + 6

    @Environment(\.colorSchemeContrast) private var contrast

    @State private var isHovered = false
    /// The pointer on the close cross itself rather than on the tab around it.
    ///
    /// See the tap gestures below: this is what keeps a click on the cross from also selecting.
    @State private var isCloseHovered = false
    @State private var renameText = ""
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Activity replaces the glyph in a fixed slot, so the title stays still as work starts.
            if icon != nil || isRunning {
                ZStack {
                    if isRunning {
                        ActivityDot(isActive: true)
                            .accessibilityLabel("Running")
                    } else if let icon {
                        TabItemIconView(
                            icon: icon, ink: isActive ? surface.ink : Palette.textSecondary
                        )
                    }
                }
                .frame(width: TabItemIconView.pageSize, height: TabItemIconView.pageSize)
            }

            if isRenaming {
                // The field's ink is the tab's, not the environment's. A terminal tab carrying a
                // dark Ghostty ground was being renamed in the window's own label colour, which
                // over that fill is a line of black on black.
                TextField("Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(isActive ? surface.ink : Palette.textPrimary)
                    .focused($isRenameFocused)
                    .frame(width: Self.renameWidth)
                    .onSubmit { onCommitRename(renameText) }
                    .onExitCommand(perform: onCancelRename)
            } else {
                // One weight for every tab, selected or not. Safari's own strip sets both at the
                // same weight and the same colour and lets the shape carry the whole answer;
                // measured on a 26 window, a selected title and an unselected one are the same
                // ink. Bolding the selected one here was doing the shape's job badly: it moved
                // the text a point as the selection landed, and it left the tab reading as a
                // label that had been emphasised rather than as a tab that had come forward.
                //
                // The colour step stays. Unified Dev's strip is denser than Safari's and its tabs are
                // leading aligned rather than centred, so dropping to the secondary label is what
                // keeps an unselected run from competing with the pane it is sitting above.
                Text(title)
                    .foregroundStyle(isActive ? surface.ink : Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        // One type size AND one weight for the whole row, set once above the branches, so
        // selection cannot change the metrics of anything. Everything a tab can hold is then on
        // the same line as everything a neighbouring tab holds, whatever each of them is showing,
        // and a tab that becomes selected does not reflow as it does so.
        .font(Typo.body)
        .frame(height: Self.labelHeight)
        // The gutter the cross stands in, kept clear at BOTH ends: one at the leading edge for the
        // cross itself, and one at the trailing edge so what is between them is centred in the tab
        // rather than pushed along by the width of a control on one side only.
        .padding(.horizontal, TabPill.contentInset + Self.closeGutter)
        // Its share of the strip, or its own width in a strip that hands out no shares. The cross
        // is placed AFTER this, which is the whole of what was wrong with it: an overlay put on
        // before the width is an overlay on the CONTENT, which is centred inside the tab, so the
        // cross rode the title around instead of standing at the tab's own edge.
        .frame(width: stripWidth)
        .frame(maxWidth: stripWidth == nil ? Self.maximumWidth : nil)
        .frame(height: TabPill.barHeight)
        .overlay(alignment: .leading) {
            closeButton.padding(.leading, TabPill.contentInset)
        }
        // The selected tab is a capsule floating on the strip's own track. See `background` and
        // `shape` for the macOS 26 Finder pattern this now follows, and for why it no longer joins
        // the pane below it the way it did under the Safari-style design this replaced.
        //
        // A closure rather than `.background(background)`. Handed a `Color`, that call resolves to
        // the `ShapeStyle` overload, whose `ignoresSafeAreaEdges` defaults to every edge, and the
        // strip sits directly under a unified toolbar. The selected tab's fill was therefore drawn
        // up through the whole toolbar inset, a block of it floating above the strip. The `View`
        // overload paints the tab's own bounds and nothing else.
        //
        // **And it takes no clicks.** The owner could drag any tab along the strip except the one
        // he was in, and the reordering hangs off `.draggable`, which `SessionTabsView` applies to
        // the whole tab: the press has to reach the TAB for a drag to begin, where a press the
        // framework resolves onto a subview reaches that subview, which has no drag on it. The
        // ancestor's tap gestures below are `simultaneous` and hear it either way, which is why
        // the selected tab still selected and still renamed while refusing to be picked up.
        //
        // Which subview is the one the selected tab has and the others do not was reached by
        // elimination rather than by measurement, and it is worth saying so. A selected tab and an
        // unselected one differ in the ink they wear, in one accessibility trait, and here. Every
        // tab draws a plate under the pointer while it is hovered, and a hovered tab drags, so the
        // plate is not it; what is left is the `matchedGeometryEffect` this branch hangs off the
        // plate, which is a geometry effect standing between the pointer and the tab.
        //
        // Either way a fill and an outline are decoration, and no press has ever been meant for
        // them: selecting, renaming and closing are all on the row or on the cross above it.
        .background { background.allowsHitTesting(false) }
        .contentShape(Rectangle())
        // A single click selects and a double click renames, which is one gesture with two
        // meanings rather than a button, so it cannot be expressed as one.
        //
        // Simultaneous, not `.exclusively(before:)`. Exclusively made the select wait for the
        // double tap to FAIL, and a double tap only fails once the system's double click interval
        // has run out, so every click on a tab sat there for about 350ms before anything happened.
        // That was most of what switching tabs felt like. Recognised side by side, the select fires
        // on the first click and the rename on the second, which is also what the Finder does: the
        // second click of a rename lands on the row the first one already selected.
        //
        // What `simultaneous` also recognises alongside is a gesture defined by a SUBVIEW, and the
        // close cross is a `Button`, which is one. So a click on the cross ran `onClose()` and this
        // as well: the window switched to the tab it was in the middle of destroying and then
        // landed on whichever neighbour the store picked. The pointer has to be on the cross before
        // it can press it, so the hover the cross already tracks is what tells the two apart. Not a
        // `SpatialTapGesture` against the cross's frame, which would have to be measured and kept
        // in step with the layout; and not `.exclusively(before:)`, for the 350ms reason above.
        .simultaneousGesture(TapGesture().onEnded { if !isCloseHovered { onSelect() } })
        .simultaneousGesture(TapGesture(count: 2).onEnded { if canRename { onStartRename() } })
        // The cross is only hit testable while the tab is hovered, so it cannot be pointed at once
        // this goes false. Cleared here as well rather than trusting the cross's own exit event to
        // arrive first, because a flag stuck true is a tab that stops selecting altogether.
        .onHover {
            isHovered = $0
            if !$0 { isCloseHovered = false }
        }
        .help(title)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        // Unnamed, so this is the DEFAULT action. Selecting is a tap gesture rather than a button
        // here, and a named action only appears in VoiceOver's actions rotor: the row said it was
        // a button and then did nothing when a reader pressed it.
        .accessibilityAction { onSelect() }
        .accessibilityActions { if canRename { Button("Rename", action: onStartRename) } }
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

    /// Nothing at rest on an unselected tab, which is why this is a builder rather than a colour.
    /// A `.clear` fill is still a view, and a view is still a thing `matchedGeometryEffect` can
    /// try to match, so the unselected case has to be absent rather than transparent.
    ///
    /// The selected tab is a capsule sitting on `TabStrip`'s track rather than a lid fused to the
    /// pane below it, inset from the row's own top and bottom so the track shows all round it: the
    /// macOS 26 Finder pattern, where the chosen tab is "a light capsule sitting on" a "grey
    /// track" and the unselected ones are plain text on it. The hover fill wears the same shape so
    /// a hovered tab and a selected one are obviously the same object in two states; it moves the
    /// opposite way from selection, which is what stops a hovered tab from being read as chosen.
    @ViewBuilder
    private var background: some View {
        if isActive {
            // Safari's selected tab: an opaque capsule that has come forward off the track, with a
            // hairline round it and no shadow. It was glass, which samples what is behind it and
            // so came out as the track with a slightly different sheen: measured on the light
            // ramp, the selected tab and the one beside it differed by less than the rule between
            // them. The pane's own ground and a rim are the whole of what makes one tab read as
            // the front one; a drop shadow on top of that drew a halo around every selection.
            shape
                .fill(surface.fill)
                .overlay { shape.strokeBorder(Palette.border.opacity(0.5), lineWidth: Metrics.hairline) }
                .padding(.vertical, Self.capsuleMargin)
                .matchedGeometryEffect(id: Self.selectionID, in: namespace)
        } else if isHovered {
            shape.fill(Palette.hover).padding(.vertical, Self.capsuleMargin)
        }
    }

    /// The fill's shape, and the hover plate's, so a hovered tab and a selected one are obviously
    /// the same object in two states. A full capsule rather than the rounded-top, square-bottom
    /// shape this used before: that shape read as the tab fusing with the pane below it, which is
    /// wrong for a control that floats on a track. A capsule floats the same way whichever end of
    /// the strip it is in, so it no longer needs `isAtPaneEdge`'s squared corner to sit flush
    /// against the pane's own rule.
    private var shape: Capsule { TabPill.shape() }

    /// Kept in the layout even when it is invisible, so no label moves when the pointer enters.
    ///
    /// Hover only, including on the selected tab. It used to sit on the selected tab at all times,
    /// on the argument that the tab you are looking at is the one you are most likely to close,
    /// and the cost of that was a cross parked in the middle of the strip whichever tab was on.
    /// Safari's strip carries no close control at rest on any tab, selected included, and the
    /// pointer is never more than a tab away on a Mac. Cmd+W and the context menu still close
    /// without a pointer at all.
    private var closeButton: some View {
        Button(action: onClose) {
            Label(closeTitle, systemImage: "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(Typo.caption)
                // A step under the label beside it, and at the label's own ink rather than a
                // paler one. Safari's cross is small against its titles and about as dark as
                // this: measured, the stroke reads mid grey on the hover fill, not a ghost. The
                // old cross had it the other way round, large enough to be the heaviest mark in
                // the strip while being too faint to look deliberate.
                .imageScale(.small)
                // Drawn in clear rather than faded with `.opacity`, which is the trick
                // `DiffLineView.commentButton` documents from a measurement: `.opacity(0)` on a
                // button or on its label took the element out of the accessibility hierarchy
                // entirely, so a hover-revealed control was one VoiceOver could never find. Clear
                // ink draws the same nothing and the element stays.
                .foregroundStyle(closeInk)
                .frame(width: Metrics.glyph, height: Metrics.glyph)
                // Out and back again: the hit box is `closeSlop` bigger on every side, and the
                // space the cross takes in the row is unchanged. See `closeSlop`.
                .padding(Self.closeSlop)
                .contentShape(Rectangle())
                .padding(-Self.closeSlop)
        }
        .buttonStyle(.borderless)
        // What the tab's own tap gesture asks before it selects. See the gestures on the row.
        .onHoverChange { isCloseHovered = $0 }
        // Hit testing still follows the hover, and deliberately: this sits at a tab's trailing
        // edge, and a close button that takes a click while invisible closes tabs somebody meant
        // to select.
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!canClose)
        .help(closeTitle)
    }

    private var closeInk: Color {
        guard isVisible else { return .clear }
        return isActive ? surface.inkMuted : Palette.textSecondary
    }

    /// On the selected tab at all times, and on any tab the pointer is over.
    ///
    /// Safari's rule, measured off its own strip: the tab you are in carries its cross without
    /// being pointed at, and the others show one as the pointer crosses them. This used to be
    /// hover alone, which left the tab most likely to be closed as the one with nothing to close
    /// it, and it was written that way from a reading of Safari that turned out to be wrong.
    private var isVisible: Bool {
        canClose && (isHovered || isActive)
    }

    /// The field only exists from the moment the strip says so, and a brand new field cannot take
    /// focus in the same pass it is created in.
    private func startEditing() async {
        guard isRenaming else { return }
        renameText = editableTitle
        try? await Task.sleep(for: .milliseconds(30))
        guard !Task.isCancelled else { return }
        isRenameFocused = true
    }
}
