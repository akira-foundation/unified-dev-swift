import SwiftUI
import Core

/// The pull request's number and the way out to it, drawn as one outlined control.
///
/// It used to be two things that looked like two things: a filled capsule carrying the number,
/// which did nothing at all when clicked, and a separate borderless arrow button beside it, which
/// was the only way out to GitHub. The number is the obvious thing to click and it was the half
/// that was inert, which is the sort of dead control people learn to distrust a whole strip over.
/// Both now open the same page through `GitHubBridge.open`. A divider still made them look like
/// separate actions, so the number and arrow share padding inside one uninterrupted outline.
///
/// Outlined rather than filled, and the numbers are measured off the control this is meant to
/// match rather than chosen: 24 points tall, 12 point text, the outline at twenty percent. Filled
/// at 11 points in a 17 point capsule it read as a badge stuck on the strip; outlined at reading
/// size it reads as what it is, which is a control you can press.
///
/// The outline takes the state's own colour, so the badge belongs to whatever the band is
/// saying. `PullRequestSummary` hands it the same tint it gives the headline and the button, and
/// passes nil where the state has no colour, which is where the secondary label colour stands in:
/// a grey rim on a grey band, rather than an accent-coloured rim on a state that is deliberately
/// colourless.
///
/// **Standard component, tinted, no hand-drawn shape.** This used to size and outline itself with
/// a `.frame`, an `.overlay(RoundedRectangle.strokeBorder(...))` and a `.contentShape`, all set on
/// the label before `.buttonStyle(.glass)` ever saw it: the style then had no rectangle to plate
/// but the one already painted, which is the same fault `InspectorToggle`'s report names. A plain
/// `.buttonStyle(.bordered)` capsule with `.tint(ink)` is what a bordered Mac button already does
/// with a colour, and `.controlSize(.small)` is what sizes it, the way `Metrics.corner`'s own note
/// says a small trailing button should be sized now.
struct PullRequestBadge: View {
    var number: Int
    var title: String
    var url: String
    /// The state's colour, or nil for the states that carry none.
    var tint: Color?

    private var ink: Color { tint ?? Palette.textSecondary }

    var body: some View {
        Button(action: open) {
            HStack(spacing: Metrics.spacingSmall) {
                // `verbatim`, and this is not a style choice. A `Text` built from a
                // `LocalizedStringKey` formats an interpolated `Int` for the current locale, so on
                // a machine set to Dutch #2631 came out as "#2.631": a pull request number with a
                // thousands separator in it, which is not a number GitHub has. The chip this
                // replaces was handed a `String` and never had the problem.
                Text(verbatim: "#\(number)")
                    // Monospaced digits, so a four digit number and a five digit one are the same
                    // shape and the badge cannot appear to jitter as a poll comes back.
                    .font(Typo.label)
                    .monospacedDigit()

                Image(systemName: "arrow.up.forward")
                    .font(Typo.caption)
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(ink)
        // One control, so one label and one action. It was two buttons, one of them unlabelled
        // and neither of them saying where it went.
        // `children: .ignore` is what collapses the two halves into one element, and it takes the
        // button trait with them, so the trait is put back by hand. Measured: without it the
        // control reports as `AXUnknown` and reads as a label rather than as something to press.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Pull request \(number), \(title)")
        .accessibilityHint("Opens on GitHub")
        .help("Open #\(number) on GitHub: \(title)")
    }

    /// The arrow's own route, unchanged and not duplicated: there is one way this app opens a
    /// pull request and this is it.
    private func open() {
        GitHubBridge.open(url)
    }
}
