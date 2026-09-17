import AppKit
import QuartzCore
import SwiftUI
import Core

@MainActor
@Observable
final class InspectorGeometry {
    static let shared = InspectorGeometry()

    private(set) var width: CGFloat = 0

    private(set) var bandWidth: CGFloat = Metrics.inspectorWidth

    private(set) var isVisible = false

    @ObservationIgnored var onChange: ((_ sliding: Bool) -> Void)?

    private init() {}

    func setInspectorWidth(_ value: CGFloat, sliding: Bool = false) {
        guard abs(width - value) > 0.5 else { return }
        width = value
        if value > 1 { bandWidth = value }
        onChange?(sliding)
    }

    func setBandVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
    }
}

struct TitleBarStrip: View {
    let app: AppModel

    let height: CGFloat

    @State private var anchor = HoverCardAnchor()

    @State private var shown: WorkspaceModel?

    private var inspector: InspectorGeometry { .shared }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .onChange(of: app.selectedModel.map { ObjectIdentifier($0) }, initial: true) { _, _ in
                if let model = app.selectedModel { shown = model }
            }
            .onChange(of: inspector.isVisible) { _, visible in
                if !visible { shown = app.selectedModel }
            }
            .environment(app)
    }

    private func bandCard(for model: WorkspaceModel) -> WorkspaceHoverCard {
        WorkspaceHoverCard.pullRequestBand(
            workspace: model.workspace,
            pullRequest: model.pullRequest,
            localWork: model.localWork
        )
    }

    @ViewBuilder
    private func ground(for model: WorkspaceModel) -> some View {
        ZStack {
            Palette.surface
            if let tint = model.pullRequest?.status(local: model.localWork).tone.color {
                tint.opacity(
                    model.pullRequest?.isOpen == false
                        ? InspectorLayout.bandOpacityQuiet
                        : InspectorLayout.bandOpacity
                )
            }
        }
    }
}

@MainActor
final class TitleBarStripController: NSTitlebarAccessoryViewController {
    private let height: CGFloat

    private var slide: InspectorSlide?
    private var startedAt: CFTimeInterval = 0
    private var frames: CADisplayLink?

    private var landing: Task<Void, Never>?

    private static let landingGrace: TimeInterval = 0.1

    init(app: AppModel, height: CGFloat) {
        self.height = height
        super.init(nibName: nil, bundle: nil)

        let host = NSHostingView(rootView: TitleBarStrip(app: app, height: height))

        host.sizingOptions = []
        host.clipsToBounds = false
        view = host
        layoutAttribute = .trailing
        fullScreenMinHeight = height

        InspectorGeometry.shared.onChange = { [weak self] sliding in self?.resize(sliding: sliding) }
        resize(sliding: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not decoded from a nib") }

    private func resize(sliding: Bool) {
        let geometry = InspectorGeometry.shared
        let target = max(geometry.width, 1)
        guard sliding, view.window != nil else {
            endSlide()
            InspectorGeometry.shared.setBandVisible(geometry.width > 1)
            apply(target)
            return
        }
        startSlide(to: target)
    }

    private func startSlide(to target: CGFloat) {
        guard abs(view.frame.width - target) > 0.5 else {
            endSlide()
            return
        }
        if InspectorGeometry.shared.width > 1 {
            InspectorGeometry.shared.setBandVisible(true)
        }
        slide = InspectorSlide(
            from: view.frame.width, to: target, seconds: Motion.inspectorSeconds
        )
        startedAt = CACurrentMediaTime()
        landing?.cancel()
        landing = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Motion.inspectorSeconds + Self.landingGrace))
            guard !Task.isCancelled else { return }
            self?.land(on: target)
        }
        guard frames == nil else { return }
        let link = view.displayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        frames = link
    }

    @objc private func step(_ sender: CADisplayLink) {
        guard let slide else {
            endSlide()
            return
        }
        let elapsed = sender.targetTimestamp - startedAt
        apply(slide.width(after: elapsed))
        guard slide.hasFinished(after: elapsed) else { return }
        land(on: slide.to)
    }

    private func land(on width: CGFloat) {
        InspectorGeometry.shared.setBandVisible(InspectorGeometry.shared.width > 1)
        apply(width)
        endSlide()
    }

    private func endSlide() {
        slide = nil
        frames?.invalidate()
        frames = nil
        landing?.cancel()
        landing = nil
    }

    private func apply(_ width: CGFloat) {
        guard abs(view.frame.width - width) > 0.01 else { return }
        view.setFrameSize(NSSize(width: width, height: height))
        view.superview?.needsLayout = true
    }
}
