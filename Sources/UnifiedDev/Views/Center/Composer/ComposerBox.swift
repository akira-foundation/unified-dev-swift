import SwiftUI

/// Only the conversation composer floats. Creation forms keep their inset field, and both
/// keep the background as the focus target so text selection still belongs to NSTextView.
struct ComposerBox: ViewModifier {
    @Binding var isFocused: Bool
    var isFloating = false
    var isDropTarget = false

    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    private var isRingVisible: Bool { isFocused && activeState.showsFocusRing }

    /// The floating composer is glass that sits against the window, so its corners follow the
    /// window's own. The inset field of a creation form is content, and keeps a fixed radius.
    private var insetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
    }

    private var shape: AnyShape {
        // The floating box follows the window's own curve, which is what every glass surface on
        // macOS 26 does and what `Metrics.corner` at twelve points did not: beside a toolbar pill
        // the box read as a square with the corners filed off.
        // Sixteen, not the window's own concentric curve: concentric on a box this tall came out
        // as a lozenge. A step up from the twelve it had, which read square beside a toolbar pill.
        isFloating
            ? AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            : AnyShape(insetShape)
    }

    /// How far the box sits below the pane it is on.
    ///
    /// Twenty two percent on the dark ramp, four in light. One value for both put a grey slab in
    /// a white window: black over white at twenty two percent is a mid grey, where the same over
    /// `#1E1E1E` is barely a step.
    private var wash: Double { scheme == .dark ? 0.22 : 0.04 }

    func body(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.gutter)
            .padding(.bottom, isFloating ? Metrics.spacingWide : Metrics.gutter)
            .background {
                shape
                    // A wash under the glass rather than instead of it: the box keeps the Liquid
                    // Glass it sits in and stops being clear enough to read the transcript
                    // through. `controlBackgroundColor` at about half, with a little of the
                    // foreground over it so the box stands a step off the pane in both
                    // appearances rather than only in light: on the dark ramp the two grounds
                    // were within a couple of units of each other and the box had no edge at all.
                    //
                    // Darker than the pane, not lighter. A writing surface that is a step up
                    // reads as another panel; a step down reads as a well, which is what a field
                    // is. Black in both appearances, but not at the same strength: see `wash`.
                    .fill(isFloating ? Palette.surfaceRaised : Palette.surfaceSunken)
                    .overlay {
                        if isFloating {
                            shape.fill(.black.opacity(wash))
                        }
                    }
                    .contentShape(shape)
                    .onTapGesture { isFocused = true }
                    .accessibilityHidden(true)
            }

        if isFloating {
            // An opaque surface, not glass, and the reason is measured in both directions.
            // Stacked, a `.glass` button on a glass box draws no plate at all. Inside a
            // `GlassEffectContainer` the system composes the two into one surface, so the buttons
            // keep a plate but lose their rims. Only an opaque box leaves both the box's edge and
            // the controls' edges visible, and the controls are the things that are pressed.
            padded
                    .overlay {
                        shape.stroke(Palette.border, lineWidth: Metrics.outline)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    .overlay {
                        shape.stroke(Palette.controlAccent, lineWidth: 2)
                            .opacity(isDropTarget ? 1 : 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
        } else {
            padded
                .overlay {
                    insetShape.strokeBorder(
                        isDropTarget ? Palette.accent : Palette.border,
                        lineWidth: isDropTarget ? Metrics.outline * 2 : Metrics.outline
                    )
                    .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.corner + 1.5)
                        .strokeBorder(Palette.focusRing, lineWidth: 3)
                        .padding(-1.5)
                        .opacity(isRingVisible ? 1 : 0)
                        .allowsHitTesting(false)
                }
        }
    }

    private var focusColour: Color {
        contrast == .increased ? Palette.focusRing : Palette.textSecondary
    }

    private var focusOpacity: Double { contrast == .increased ? 1 : 0.2 }
}

extension View {
    func composerBox(
        isFocused: Binding<Bool>, isDropTarget: Bool = false, isFloating: Bool = false
    ) -> some View {
        modifier(ComposerBox(
            isFocused: isFocused, isFloating: isFloating, isDropTarget: isDropTarget
        ))
    }
}
