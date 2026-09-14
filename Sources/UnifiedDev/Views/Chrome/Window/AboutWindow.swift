import AppKit
import SwiftUI
import Core

/// The window behind "About Unified Dev".
///
/// It replaces `NSApplication.orderFrontStandardAboutPanel`, which drew an icon, the word Unified Dev
/// and a version number. Every one of those is true and none of them belongs to this app in
/// particular: that panel is the same panel in every Mac application, and the only thing it can be
/// given beyond the bundle's own keys is a paragraph of credits. No mark, no typeface, no ground.
///
/// Unified Dev has a site at unified-dev.akira-io.com built on one ramp and one pair of typefaces, and an About
/// window is the one window small enough to be that site and still be a Mac window. So this is the
/// site's own furniture: the plinth with the mark on it, the name set in the display face, a mono spec line
/// under it, and below the rule the site's makers section, ending in the footer's credit strip.
/// `public/brand/PALETTE.md` and `resources/css/app.css` in the unified-dev.akira-io.com repository
/// are where each of those numbers is from.
///
/// One instance, kept here. `isReleasedWhenClosed` defaults to true for a window built in code, so
/// without the line below the second visit would message a window that had been deallocated by the
/// first close.
@MainActor
enum AboutWindow {
    private static var window: NSWindow?

    /// Opens it, or brings the one that is already open forward.
    ///
    /// Deliberately not re-centred on the second visit. A window the user has dragged somewhere
    /// and left open should come forward where they put it; jumping back to the middle of the
    /// screen under their pointer reads as a second window having opened.
    static func show() {
        let existing = window ?? make()
        window = existing
        existing.makeKeyAndOrderFront(nil)
    }

    private static func make() -> NSWindow {
        let host = NSHostingView(rootView: AboutView())
        // Asked for rather than written down, so the numbers in `AboutView` are the only ones and
        // a change to its padding cannot leave the window an inch too tall.
        let size = host.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            // No `.resizable` and no `.miniaturizable`: there is nothing in here to resize and
            // nothing to come back to. `.fullSizeContentView` is what lets the plinth run up
            // behind the title bar, which it has to do, because the alternative is a strip of flat
            // window background above a gradient and a visible seam between the two.
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        // Set even though it is hidden: it is what the Window menu and the accessibility hierarchy
        // call this window.
        window.title = "About Unified Dev"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // The title bar is transparent and carries no title, so there is no strip left to drag the
        // window by. The plinth becomes that strip instead.
        window.isMovableByWindowBackground = true
        // Absent rather than drawn greyed out. AppKit still draws both buttons for a window whose
        // style mask lacks them, and two dead circles beside a live one is the sort of detail an
        // About window is judged on.
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = host
        window.setContentSize(size)
        window.center()
        // Escape as well as Cmd+W, because this is a window you read and then put away and there
        // is nothing in it either key could have meant instead. See `WindowRoles`.
        WindowRoles.mark(window, as: .reading)
        return window
    }
}

/// What that window draws. Every number in it lives here; every sentence and every address lives
/// in `AppSite` and `BuildIdentity`, because a string typed into this file is a string nothing in
/// `Tests/CoreTests` can hold still.
private struct AboutView: View {
    /// Handed to the stamp rather than read by it, so a panel that is being redrawn rather than
    /// opened can hold it still without asking about the system setting twice.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Wide enough that the product summaries set beside their marks without an orphaned line,
    /// and no wider: the window is a column of centred things and a short list, and surplus width
    /// reads as a dialog that forgot its content. 360 was the width before the makers section
    /// arrived and every summary broke mid-phrase at it; 420 held until the marks arrived and
    /// their column pushed one maker's summary into a two word second line.
    private static let width: CGFloat = 460

    /// The app's own icon at the size the site's closing section draws the mark at, scaled for a
    /// window rather than a page. Read out of the running bundle rather than shipped a second time
    /// here, so the window can never show a mark the app has stopped using.
    private static let markSize: CGFloat = 96

    /// See the note where they are applied: the brand band is off the spacing scale on purpose.
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

    // MARK: The plinth

    private var plinth: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Self.markSize, height: Self.markSize)
                // The site seats every screenshot and the closing mark on a shadow rather than
                // letting them float on the ground. `.shot` is `0 30px 80px -40px rgb(0 0 0 /
                // 70%)`; this is the same shadow at a window's scale.
                .shadow(color: .black.opacity(0.55), radius: 16, y: 9)
                .accessibilityHidden(true)

            // The system face, light and tracked in; see `Typo.display`.
            Text(verbatim: "Unified Dev")
                .font(Typo.display)
                .tracking(Typo.displayTracking)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Metrics.spacingWide)

            // The site's `.hero__spec`: mono, small, dimmed, with a middle dot between the parts.
            Text(versionLine)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Metrics.spacing)

            // The app's own address, up here rather than in the footer, and in exactly one of
            // the two. This is the identity block, and the person most likely to want this link
            // is hunting for the site, the changelog or the release notes, which is a hunt that
            // starts at the version line and stops when an address appears under it. The footer
            // is the site's own signature, and a second address beside it would turn the
            // signature into a link list.
            Link(AppSite.host, destination: AppSite.url)
                .font(Typo.codeSmall)
                .foregroundStyle(Palette.link)
                .underline()
                .padding(.top, Metrics.spacingWide + Metrics.spacingSmall)
        }
        .frame(maxWidth: .infinity)
        // The brand plinth's own numbers, as in `WelcomeView`, and off the spacing scale for the
        // reason given there: this is a fixed-size window's header of display type,
        // measured against the title bar rather than against a row of controls.
        .padding(.top, Self.plinthTop)
        .padding(.bottom, Self.plinthBottom)
        .background {
            // `.ignoresSafeArea` because this is the view builder overload of `background`,
            // which respects the safe area that the ShapeStyle overload ignores by default.
            // Without it the plinth stops at the title bar and leaves a strip of flat window
            // background above the surface, which is exactly the seam `.fullSizeContentView`
            // exists to prevent.
            Palette.surface
                .ignoresSafeArea(edges: .top)
        }
    }

    /// What the AppKit panel used to print under the name, except honest about which build it is.
    ///
    /// Never a literal, and never the two version keys read raw. `Resources/Info.plist` carries a
    /// fixed `0.1.0 (1)` that only the release workflow overwrites, so reading those keys made
    /// every build on this machine claim a version that had never been released. `BuildIdentity`
    /// is the type that knows the difference; see its head.
    ///
    /// The date the build was assembled is passed in beside it rather than formatted here, and
    /// which builds show one at all is `BuildIdentity`'s decision rather than this view's. There
    /// are usually several development builds on this machine at once and the line is identical in
    /// all of them, so the timestamp is the answer to the only question this line gets asked; a
    /// release keeps the version it shares with everybody else and no timestamp. See
    /// `BuildTimestamp`.
    private var versionLine: String {
        BuildIdentity.read(from: .main).line(built: BuildTimestamp.read(from: .main))
    }

    // MARK: The credit strip

    private var credit: some View {
        VStack(spacing: Metrics.spacingSmall) {
            // Underlined, which `Palette.link` is explicit is not decoration: it is what makes a
            // link findable without colour vision.
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
        // The chrome colour, which is what every strip of small print in this app stands on. Not
        // `surfaceSunken`: in dark that is two units off Abyss and the footer disappeared into the
        // bottom of the plinth with only the rule left to say there were two things.
        .background(Palette.controlStrip)
    }

    /// `NSHumanReadableCopyright`, which is where macOS reads it from too: the Finder's Get Info
    /// panel shows that key, and so did the panel this window replaces. One string, in the plist,
    /// rather than a second copy here that would drift from it. `Tools/build.sh` re-stamps the
    /// year when it assembles the bundle, so the value read here is current without anyone
    /// remembering January; see the comment there.
    private var copyright: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }
}
