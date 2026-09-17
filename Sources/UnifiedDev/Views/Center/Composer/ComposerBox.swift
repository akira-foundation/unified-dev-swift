import SwiftUI
import Core

struct ComposerBox: ViewModifier {
    @Binding var isFocused: Bool
    var isFloating = false
    var isDropTarget = false
    var isBusy = false

    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.controlActiveState) private var activeState
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    private var isRingVisible: Bool { isFocused && activeState.showsFocusRing }

    private var insetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
    }

    private var shape: AnyShape {
        isFloating
            ? AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            : AnyShape(insetShape)
    }

    private var wash: Double { scheme == .dark ? 0.22 : 0.04 }

    func body(content: Content) -> some View {
        let padded = content
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, Metrics.gutter)
            .padding(.bottom, isFloating ? Metrics.spacingWide : Metrics.gutter)
            .background {
                shape
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
                    .overlay {
                        shape.stroke(busyStroke, lineWidth: BusyCrest.thickness)
                            .opacity(isBusy ? 1 : 0)
                            .animation(.easeInOut(duration: 0.25), value: isBusy)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                            .onChange(of: isBusy, initial: true) { _, busy in
                                guard busy, !reduceMotion else { return }
                                angle = 0
                                withAnimation(
                                    .linear(duration: Self.lap).repeatForever(autoreverses: false)
                                ) { angle = 360 }
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

    private var busyStroke: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Palette.running.opacity(0.08), location: 0),
                .init(color: Palette.running.opacity(0.08), location: 0.72),
                .init(color: Palette.running, location: 0.88),
                .init(color: Palette.running.opacity(0.08), location: 1),
            ],
            center: .center,
            angle: .degrees(reduceMotion ? 0 : angle)
        )
    }

    private static let lap = 3.0

    private var focusColour: Color {
        contrast == .increased ? Palette.focusRing : Palette.textSecondary
    }

    private var focusOpacity: Double { contrast == .increased ? 1 : 0.2 }
}

extension View {
    func composerBox(
        isFocused: Binding<Bool>,
        isDropTarget: Bool = false,
        isFloating: Bool = false,
        isBusy: Bool = false
    ) -> some View {
        modifier(ComposerBox(
            isFocused: isFocused, isFloating: isFloating, isDropTarget: isDropTarget, isBusy: isBusy
        ))
    }
}
