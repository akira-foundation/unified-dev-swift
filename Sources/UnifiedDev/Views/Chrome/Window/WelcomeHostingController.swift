import AppKit
import Core
import SwiftUI

@MainActor
final class WelcomeHostingController: NSHostingController<AnyView> {
    private let contentWidth: CGFloat
    private let screen = WelcomeScreenHeight()
    private var resizeIsScheduled = false

    init(rootView: some View, contentWidth: CGFloat) {
        self.contentWidth = contentWidth
        super.init(rootView: AnyView(rootView))
        sizingOptions = []
        self.rootView = AnyView(
            WelcomeScreenScope(screen: screen) { rootView }
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { [weak self] _ in
                    self?.scheduleResize()
                }
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not decoded from a nib") }

    func fittingContentSize() -> CGSize {
        measuredContentSize()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        screen.read(from: view.window)
    }

    private func scheduleResize() {
        guard !resizeIsScheduled else { return }
        resizeIsScheduled = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.resizeIsScheduled = false
            self.resizeWindow()
        }
    }

    private func resizeWindow() {
        guard let window = view.window else { return }
        screen.read(from: window)
        let size = measuredContentSize()
        let current = view.bounds.size
        guard abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5
        else { return }

        let oldFrame = window.frame
        let fitted = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        let visible = window.screen?.visibleFrame ?? oldFrame
        let newFrame = CentredWindowPlacement.frame(size: fitted.size, keepingTopOf: oldFrame, visible: visible)
        window.setFrame(newFrame, display: true)
    }

    private func measuredContentSize() -> CGSize {
        let proposed = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        let measured = sizeThatFits(in: proposed)
        guard measured.height.isFinite, measured.height > 0 else {
            return CGSize(width: contentWidth, height: max(1, view.bounds.height))
        }
        return CGSize(width: contentWidth, height: ceil(measured.height))
    }
}
