import AppKit
import SwiftUI
import Core

/// The first thing Unified Dev ever says, and the only screen in the app with nothing to do on it.
///
/// It exists because the window used to open straight onto four probes, which meant a new Unified Dev
/// introduced itself by listing what your Mac might be missing. That is a form, and the app it
/// belongs to feels like a utility rather than like something anybody made. So the plinth, which
/// on the next screen is a band at the top, is the whole window here: the mark, the name and one
/// line saying what Unified Dev does. One press and it is gone.
///
/// The cost of it is one press for somebody who has already read it, and that is paid for in
/// `OnboardingFlow.firstStep`: this screen is where a FIRST run opens, and the Help menu and a
/// later broken launch both open on the checks instead. Somebody who has been here before is not
/// greeted twice, and can still walk back to it.
///
/// Nothing here waits for anything. The probes are started when the window opens, so they run
/// underneath this screen and the checks are usually already answered by the time anybody presses
/// on. See `SetupInspection.presentChecks`, which is what holds the settling back so the second
/// screen still has its moment rather than opening onto a finished list.
struct WelcomeGreeting: View {
    /// False when somebody has walked back to this screen from the checks. A return is not an
    /// arrival, and replaying the whole opening on one is how a nice moment becomes a wait.
    let isFirstVisit: Bool
    /// What the one button says, from `OnboardingFlow` rather than from here, so the words that
    /// name the next screen live with the sequence that decides which screen that is.
    let continueTitle: String?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entered = false

    private static let markSize: CGFloat = 104
    /// The height BELOW the title bar; the surface behind it runs up past that, so the window is
    /// this plus the title bar's inset and the plinth fills all of it.
    private static let height: CGFloat = 424

    /// The surface is the BACKGROUND, and only the background ignores the safe area, which is the
    /// arrangement the checks step has always had.
    ///
    /// It used to be one ZStack, gradient and all, with `.frame(height: 424)` and then
    /// `.ignoresSafeArea(edges: .top)` over the whole thing. Ignoring the safe area moved the
    /// drawing up under the title bar without taking the title bar's inset back out of the fitting
    /// size, so the hosting view asked for 456 points and the plinth painted 424 of them from the
    /// top down. What was left was 27 points of flat `Palette.surface` along the bottom edge with
    /// a hard horizontal line above it, on the first screen the app ever draws. A background is
    /// not asked how big it is, so it bleeds upwards and fills downwards and there is no strip.
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
                // Set on the next runloop pass rather than inside `onAppear` itself, because a
                // state change made while the view is being installed is applied without the
                // animation and the whole entrance was skipped.
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

            // The only sentence on the screen that says what the app is, so it is set in the face
            // and at the size the app sets a sentence in: `Typo.body`, the same rung as the
            // verdict line on the checks screen. The two screens are one window and the sentence
            // that introduces Unified Dev and the sentence that reports on your Mac should not read as
            // two different kinds of text.
            //
            // It was mono, and going up a rung within mono did not fix it, because the size was
            // never the whole fault. Mono is this app's voice for what a machine said: a version,
            // a path, a command, an account. This sentence is English, and English set in mono
            // reads as data, which is the same mistake the checks column's state words used to
            // make. Between a display line and a large button, at the floor of
            // the scale in a face that is wider and greyer per word than the text around it, the
            // one line explaining the product was the hardest thing in the window to read.
            Text("A worktree, an agent and a branch for every task you describe")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Metrics.inset + Metrics.spacingSmall)
                .padding(.horizontal, Metrics.pane)
                .modifier(Rise(entered: entered, animation: step(0.28)))

            // The fallback is unreachable and is a button rather than nothing on purpose. A nil
            // title means the sequence has nowhere to go from here, which the greeting never does;
            // if that ever changed, a screen with one control and no way off it is the worse of
            // the two failures.
            Button(continueTitle ?? "Continue", action: onContinue)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                // The user's control accent, matching primary actions throughout macOS.
                .tint(Palette.controlAccent)
                .controlSize(.large)
                .padding(.top, Metrics.pane + Metrics.inset)
                .modifier(Rise(entered: entered, animation: step(0.40)))

            // Nothing under the button. There WAS a line here naming what the next screen goes
            // looking for, and it was answering a question the button had stopped asking: it was
            // written when the button said "Check my Mac", which could be read as anything from a
            // hardware scan to something rummaging through the disk. "See what Unified Dev needs"
            // already says that pressing it shows you a list, so the line under it was the screen
            // explaining its own button.
        }
        .padding(.top, Metrics.pane + Metrics.inset)
        .frame(maxWidth: .infinity)
    }

    /// One element of the entrance, and its place in the queue.
    ///
    /// The whole sequence is a little under a second, from the mark to the button, and every
    /// element is faded and lifted eight points rather than slid, scaled or sprung. It is an app
    /// opening its door, and a door that bounced would be a splash screen. Reduce Motion is not
    /// given a slower version of it: `entered` is already true on the first frame, so there is
    /// nothing to play at all.
    ///
    /// The delays are spaced rather than counted, so dropping the last element shortens the
    /// entrance instead of leaving a beat of nothing at the end of it.
    private func step(_ delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay)
    }
}

/// Faded and lifted into place. Its own modifier because three elements do the same thing at
/// three different moments, and three copies of two lines is three places for one of them to
/// drift. Four until the line under the button went. The mark is not one of them: it scales as
/// well as fades, so it is written out at the call site.
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
