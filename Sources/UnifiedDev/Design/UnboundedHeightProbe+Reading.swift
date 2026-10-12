import AppKit
import Core
import ScreenCaptureKit
import SwiftUI

extension UnboundedHeightProbe {
    static let shortSentence = "Ready."

    static let rigSize = NSSize(width: 1_600, height: 900)

    struct Control {
        var before = DrawnWindow()
        var after = DrawnWindow()

        var discriminates: Bool { before.letTheHeightEscape(against: after) }

        var json: [String: JSONValue] {
            [
                "before": before.json,
                "after": after.json,
                "discriminates": .bool(discriminates),
            ]
        }
    }

    struct Looked {
        var seen = DrawnWindow()
        var baseline = DrawnWindow()
        var shortened = DrawnWindow()
        var inApp: DrawnWindow?
        var inAppWithout: DrawnWindow?
        var place = "nowhere"

        var escaped: Bool { seen.letTheHeightEscape(against: baseline) }

        var json: JSONValue {
            .object([
                "seen": seen.json,
                "baseline": baseline.json,
                "shortened": shortened.json,
                "inApp": inApp?.json ?? .null,
                "inAppWithout": inAppWithout?.json ?? .null,
                "measuredIn": .string(place),
            ])
        }
    }

    struct Drawn {
        var home = WindowInk.unreadable
        var looked: [String: Looked] = [:]

        subscript(key: String) -> Looked { looked[key] ?? Looked() }

        var json: [String: JSONValue] {
            ["home": home.json, "looked": .object(looked.mapValues(\.json))]
        }
    }

    static func controls() async -> Control {
        Control(
            before: await seen(ofRig: ArchiveStanding(bounded: false)),
            after: await seen(ofRig: ArchiveStanding(bounded: true))
        )
    }

    static func readWindows(
        app: AppModel, window: NSWindow, content: NSView, staging: Staging, drawing: DrawnWindow
    ) async -> Drawn {
        var drawn = Drawn()

        app.selection = .home
        drawn.home = await ink(of: window, content: content)

        for subject in UnboundedHeightSubject.all {
            drawn.looked[subject.key] = Looked(
                seen: await seen(
                    ofRig: view(
                        for: subject, in: staging, saying: UnboundedHeightSubject.longSentence
                    )
                ),
                baseline: drawing,
                shortened: await seen(
                    ofRig: view(for: subject, in: staging, saying: shortSentence)
                ),
                place: "the centre column of a split view, against the same column holding the "
                    + "archive card as the #241 fix leaves it"
            )
        }

        await readInspectorNotice(app: app, window: window, content: content, into: &drawn)
        await readAgentQuestion(app: app, window: window, content: content, into: &drawn)
        app.selection = .home
        return drawn
    }

    private static func readInspectorNotice(
        app: AppModel, window: NSWindow, content: NSView, into drawn: inout Drawn
    ) async {
        guard let workspace = app.workspaces.first else { return }
        let model = app.model(for: workspace)
        app.selection = .workspace(workspace.id)
        model.pullRequestNotice = PullRequestNotice(
            tone: .failure, title: shortSentence, message: shortSentence, details: nil
        )
        _ = await ink(of: window, content: content)
        for said in [UnboundedHeightSubject.longSentence, shortSentence] {
            model.pullRequestNotice = PullRequestNotice(
                tone: .failure, title: said, message: said, details: nil
            )
            let reading = DrawnWindow(
                ink: await ink(of: window, content: content), height: window.frame.height
            )
            if said == shortSentence {
                drawn.looked["inspector-notice"]?.inAppWithout = reading
            } else {
                drawn.looked["inspector-notice"]?.inApp = reading
            }
        }
        model.pullRequestNotice = nil
    }

    private static func readAgentQuestion(
        app: AppModel, window: NSWindow, content: NSView, into drawn: inout Drawn
    ) async {
        var asking: [(Workspace, Bool)] = []
        for branch in [Self.wrappingQuestionBranch, Self.plainQuestionBranch] {
            guard let workspace = app.workspaces.first(where: { $0.branch == branch })
            else { return }
            let model = app.model(for: workspace)
            await model.reloadSessions()
            guard model.activeTranscript?.rows.contains(where: \.isQuestion) == true
            else { return }
            asking.append((workspace, branch == Self.wrappingQuestionBranch))
        }
        app.selection = .workspace(asking[0].0.id)
        _ = await ink(of: window, content: content)
        for (workspace, isLong) in asking {
            app.selection = .workspace(workspace.id)
            let reading = DrawnWindow(
                ink: await ink(of: window, content: content), height: window.frame.height
            )
            if isLong {
                drawn.looked["agent-question-option"]?.inApp = reading
            } else {
                drawn.looked["agent-question-option"]?.inAppWithout = reading
            }
        }
    }

    static let wrappingQuestionBranch = "unbounded-height"

    static let plainQuestionBranch = "reader"

    static func ink(of window: NSWindow, content: NSView) async -> WindowInk {
        try? await Task.sleep(for: .milliseconds(2_300))
        let onArrival = await WindowCapture.read(window)
        window.layoutIfNeeded()
        content.layoutSubtreeIfNeeded()
        window.contentView?.needsDisplay = true
        window.displayIfNeeded()
        try? await Task.sleep(for: .milliseconds(600))
        let afterRedraw = await WindowCapture.read(window)
        captures.append(.object([
            "onArrival": onArrival.json, "afterRedraw": afterRedraw.json,
            "window": .integer(window.windowNumber),
            "frameHeight": .number(Double(window.frame.height)),
        ]))
        return WindowInk(onArrival: onArrival.ink, afterRedraw: afterRedraw.ink)
    }

    static var captures: [JSONValue] = []

    static func seen(ofRig subject: some View) async -> DrawnWindow {
        let host = NSHostingView(rootView: SplitRig { subject })
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: rigSize),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(rigSize)
        window.orderFrontRegardless()
        window.setFrameOrigin(NSPoint(x: -30_000, y: -30_000))
        let reading = DrawnWindow(
            ink: await ink(of: window, content: host), height: window.frame.height
        )
        window.orderOut(nil)
        window.contentView = nil
        return reading
    }
}

private struct SplitRig<Subject: View>: View {
    @ViewBuilder var subject: Subject

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(0..<12, id: \.self) { row in
                    Label("Workspace \(row)", systemImage: "square.stack")
                }
            }
            .navigationSplitViewColumnWidth(
                min: UnifiedDevApp.sidebarMinimumWidth,
                ideal: Metrics.sidebarWidth,
                max: UnifiedDevApp.sidebarMaximumWidth
            )
        } detail: {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                subject
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, Metrics.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct ArchiveStanding: View {
    var bounded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.spacingWide) {
            Image(systemName: "clock")
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            if bounded {
                sentence.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                sentence.fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.textTertiary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: Metrics.corner)
        )
    }

    private var sentence: some View {
        Text(UnboundedHeightSubject.longSentence)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
    }
}
