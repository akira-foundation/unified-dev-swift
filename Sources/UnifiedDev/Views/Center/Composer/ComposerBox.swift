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
                    // through. Two fifths of `controlBackgroundColor`, which is the system's own
                    // ground for a field.
                    .fill(isFloating ? Palette.surfaceRaised : Palette.surfaceSunken)
                    .contentShape(shape)
                    .onTapGesture { isFocused = true }
                    .accessibilityHidden(true)
            }

        if isFloating {
            // The box's glass and the glass of every control inside it, composed rather than
            // stacked. Glass does not sample glass: a `.glass` button drawn on top of a glass box
            // comes out with no plate at all, which is why the footer read as bare symbols beside
            // one visible pill. A container is what makes the system compose the two.
            // The box is a surface, not glass, and that is a choice forced by a measurement:
            // glass does not sample glass, so every `.glass` button inside a glass box came out
            // with no plate and no shadow at all. The glass belongs to the controls, which are
            // the things that are pressed; the box is what they sit on.
            padded
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
