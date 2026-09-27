import AppKit
import SwiftUI
import Core

enum WelcomeHero {
    case appIcon
    case symbol(String, Color)
}

struct WelcomeLink {
    let title: String
    var isEnabled = true
    let action: () -> Void
}

struct WelcomeFooter {
    let backTitle: String
    let forwardTitle: String
    let progress: OnboardingProgress
    var canGoBack = true
    var isForwardEnabled = true
    let back: () -> Void
    let forward: () -> Void
}

enum WelcomeMetrics {
    static let windowWidth: CGFloat = 760
    static let column: CGFloat = 480
    static let titleColumn: CGFloat = 600
    static let subtitleColumn: CGFloat = 470
    static let icon: CGFloat = 112
    static let symbol: CGFloat = 66
    static let titleSize: CGFloat = 36
    static let subtitleSize: CGFloat = 15
    static let titleTracking: CGFloat = -0.8
    static let head: CGFloat = 44
    static let terminal: CGFloat = 220
    static let rowSpacing: CGFloat = 18
    static let symbolColumn: CGFloat = 34
}

struct WelcomeStage<Content: View>: View {
    let hero: WelcomeHero
    let title: String
    let subtitle: String
    var link: WelcomeLink?
    let footer: WelcomeFooter
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.welcomeVisibleHeight) private var visibleHeight

    private var heightLimit: CGFloat {
        WelcomeSheetFit.heightLimit(forVisibleHeight: visibleHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            head

            ScrollView(.vertical) {
                content()
                    .frame(width: WelcomeMetrics.column, alignment: .leading)
                    .welcomeDrawn("body", of: title)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Metrics.pane + Metrics.spacingWide)
                    .padding(.bottom, Metrics.pane)
            }
            .scrollBounceBehavior(.basedOnSize)

            if let link {
                anchorLink(link)
            }

            Hairline()

            controls
        }
        .frame(maxWidth: .infinity, maxHeight: heightLimit)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        }
        .coordinateSpace(.named(WelcomeDrawn.space))
        .welcomeDrawn("stage", of: title)
    }

    private var head: some View {
        VStack(spacing: 0) {
            heroMark
                .frame(width: WelcomeMetrics.icon, height: WelcomeMetrics.icon)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: WelcomeMetrics.titleSize, weight: .bold))
                .tracking(WelcomeMetrics.titleTracking)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: WelcomeMetrics.titleColumn)
                .padding(.top, Metrics.pane)
                .id(title)
                .transition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : Motion.arrival, value: title)
                .accessibilityIdentifier("welcome-title")
                .welcomeDrawn("title", of: title)

            Text(subtitle)
                .font(.system(size: WelcomeMetrics.subtitleSize))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: WelcomeMetrics.subtitleColumn)
                .padding(.top, Metrics.inset)
                .id(subtitle)
                .transition(reduceMotion ? .identity : .opacity)
                .animation(reduceMotion ? nil : Motion.arrival, value: subtitle)
                .welcomeDrawn("subtitle", of: title)
        }
        .padding(.top, WelcomeMetrics.head)
        .padding(.horizontal, Metrics.pane)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var heroMark: some View {
        switch hero {
        case .appIcon:
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: WelcomeMetrics.icon, height: WelcomeMetrics.icon)
        case .symbol(let name, let ink):
            Image(systemName: name)
                .font(.system(size: WelcomeMetrics.symbol))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(ink)
        }
    }

    private func anchorLink(_ link: WelcomeLink) -> some View {
        Button(link.title) { link.action() }
            .linkButton()
            .font(Typo.body)
            .disabled(!link.isEnabled)
            .opacity(link.isEnabled ? 1 : 0.5)
            .padding(.bottom, Metrics.pane)
            .accessibilityIdentifier("welcome-link")
            .welcomeDrawn("link", of: title)
    }

    private var controls: some View {
        HStack(spacing: Metrics.inset) {
            WelcomeProgressDots(progress: footer.progress)
                .welcomeDrawn("dots", of: title)

            Spacer(minLength: 0)

            Button(footer.backTitle) { footer.back() }
                .disabled(!footer.canGoBack)
                .accessibilityIdentifier("welcome-back")
                .welcomeDrawn("back", of: title)

            Button(footer.forwardTitle) { footer.forward() }
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .keyboardShortcut(.defaultAction)
                .disabled(!footer.isForwardEnabled)
                .accessibilityIdentifier("welcome-forward")
                .welcomeDrawn("forward", of: title)
        }
        .controlSize(.large)
        .padding(.horizontal, Metrics.pane)
        .padding(.vertical, Metrics.inset + Metrics.spacingSmall)
    }
}
