import SwiftUI

/// Only the conversation composer floats. Creation forms keep their inset field, and both
/// keep the background as the focus target so text selection still belongs to NSTextView.
struct ComposerBox: ViewModifier {
    @Binding var isFocused: Bool
    var isFloating = false
    var isDropTarget = false

    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorSchemeContrast) private var contrast

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
                    .fill(isFloating ? Palette.surfaceRaised : Palette.surfaceSunken)
                    .overlay {
                        if isFloating {
                            shape.fill(Color.primary.opacity(0.06))
                        }
                    }
                    .contentShape(shape)
                    .onTapGesture { isFocused = true }
                    .accessibilityHidden(true)
            }

        if isFloating {
            // The box wears the same material as the controls inside it, in one container so the
            // system composes the two instead of stacking them. Stacked, a glass button on a
            // glass box draws no plate at all; composed, and with the controls six points apart
            // rather than two, each keeps its own.
            GlassEffectContainer(spacing: Metrics.spacing) {
                padded
                    .glassEffect(.regular, in: shape)
                    // The box's own edge, so it reads as a surface rather than as a patch of the
                    // pane, and the drop target's over it.
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
