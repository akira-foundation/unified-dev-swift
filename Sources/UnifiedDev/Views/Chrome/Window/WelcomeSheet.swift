import AppKit
import SwiftUI
import Core

struct WelcomeSheet<Content: View, Secondary: View>: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    @ViewBuilder let secondary: () -> Secondary
    @ViewBuilder let content: () -> Content

    private static var markSize: CGFloat { 72 }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .accessibilityHidden(true)

            Text(title)
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Metrics.inset + Metrics.spacingWide)

            Text(subtitle)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Metrics.spacing)
                .padding(.horizontal, Metrics.pane)

            content()
                .padding(.top, Metrics.pane + Metrics.spacingSmall)

            secondary()
                .padding(.top, Metrics.inset)

            Button(actionTitle, action: action)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.top, Metrics.pane)
        }
        .padding(.horizontal, Metrics.pane + Metrics.spacingWide)
        .padding(.top, Metrics.pane + Metrics.inset)
        .padding(.bottom, Metrics.pane)
        .frame(maxWidth: .infinity)
        .background {
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
    }
}

extension WelcomeSheet where Secondary == EmptyView {
    init(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle,
            action: action,
            secondary: { EmptyView() },
            content: content
        )
    }
}
