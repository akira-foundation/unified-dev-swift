import AppKit
import SwiftUI
import Core

struct WelcomeGreeting: View {
    let isFirstVisit: Bool
    let continueTitle: String?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false

    private static let markSize: CGFloat = 104
    private static let height: CGFloat = 424

    var body: some View {
        content
        .frame(height: Self.height)
        .clipped()
        .background {
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            guard !entered else { return }
            if reduceMotion || !isFirstVisit {
                entered = true
            } else {
                DispatchQueue.main.async { entered = true }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
                .accessibilityHidden(true)
                .opacity(entered ? 1 : 0)
                .scaleEffect(entered ? 1 : 0.88)
                .animation(step(0), value: entered)

            Text(verbatim: "Welcome to Unified Dev")
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Metrics.pane + Metrics.spacingWide)
                .modifier(Rise(entered: entered, animation: step(0.16)))

            Text("A worktree, an agent and a branch for every task you describe")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Metrics.inset + Metrics.spacingSmall)
                .padding(.horizontal, Metrics.pane)
                .modifier(Rise(entered: entered, animation: step(0.28)))

            Button(continueTitle ?? "Continue", action: onContinue)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .controlSize(.large)
                .padding(.top, Metrics.pane + Metrics.inset)
                .modifier(Rise(entered: entered, animation: step(0.40)))
        }
        .padding(.top, Metrics.pane + Metrics.inset)
        .frame(maxWidth: .infinity)
    }

    private func step(_ delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay)
    }
}

private struct Rise: ViewModifier {
    let entered: Bool
    let animation: Animation?

    func body(content: Content) -> some View {
        content
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : 8)
            .animation(animation, value: entered)
    }
}
