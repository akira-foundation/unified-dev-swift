import AppKit
import SwiftUI
import Core

@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    static func show() {
        let existing = window ?? make()
        window = existing
        existing.makeKeyAndOrderFront(nil)
    }

    private static func make() -> NSWindow {
        let host = NSHostingView(rootView: AboutView())
        let size = host.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "About Unified Dev"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = host
        window.setContentSize(size)
        window.center()
        WindowRoles.mark(window, as: .reading)
        return window
    }
}

private struct AboutView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let width: CGFloat = 460

    private static let markSize: CGFloat = 96

    private static let plinthTop: CGFloat = 38
    private static let plinthBottom: CGFloat = 26

    var body: some View {
        VStack(spacing: 0) {
            plinth
            rule
            rule
            credit
        }
        .frame(width: Self.width)
    }

    private var rule: some View {
        Rectangle()
            .fill(Palette.border)
            .frame(height: Metrics.hairline)
    }

    private var plinth: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                .shadow(color: .black.opacity(0.55), radius: 16, y: 9)
                .accessibilityHidden(true)

            Text(verbatim: "Unified Dev")
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Metrics.spacingWide)

            Text(versionLine)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Metrics.spacing)

            Link(AppSite.host, destination: AppSite.url)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.link)
                .underline()
                .padding(.top, Metrics.spacingWide + Metrics.spacingSmall)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Self.plinthTop)
        .padding(.bottom, Self.plinthBottom)
        .background {
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
    }

    private var versionLine: String {
        BuildIdentity.read(from: .main).line(built: BuildTimestamp.read(from: .main))
    }

    private var credit: some View {
        VStack(spacing: Metrics.spacingSmall) {
            Link(AppSite.host, destination: AppSite.url)
                .foregroundStyle(Palette.link)
                .underline()
                .font(Typo.codeSmall)

            if let copyright {
                Text(copyright)
                    .font(Typo.codeTiny)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Metrics.inset + Metrics.spacingTight)
        .padding(.horizontal, Metrics.pane)
        .background(Palette.controlStrip)
    }

    private var copyright: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }
}
