import SwiftUI

struct TranscriptHoverOverlay: View {
    var host: TranscriptHoverHost

    private static let settleDelay = Duration.milliseconds(40)

    private struct Measurement: Hashable {
        var identity: String
        var availableWidth: CGFloat
        var size: CGSize

        func fits(_ request: TranscriptHoverRequest, availableWidth: CGFloat) -> Bool {
            identity == request.card.identity && self.availableWidth == availableWidth
        }
    }

    @State private var measured: Measurement?
    @State private var settled: Measurement?

    var body: some View {
        GeometryReader { geometry in
            let pane = geometry.frame(in: .global)
            let request = host.request
            let size = settled.flatMap { measurement in
                request.flatMap {
                    measurement.fits($0, availableWidth: pane.width) ? measurement.size : nil
                }
            }

            ZStack(alignment: .topLeading) {
                if let request, size == nil {
                    card(for: request, availableWidth: pane.width)
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
                            measured = Measurement(
                                identity: request.card.identity,
                                availableWidth: pane.width,
                                size: newSize
                            )
                        }
                        .opacity(0)
                }

                Color.clear
                    .popover(
                        isPresented: Binding(
                            get: { size != nil },
                            set: { if !$0 { host.request = nil } }
                        ),
                        attachmentAnchor: .rect(.rect(anchor(for: request, in: pane))),
                        arrowEdge: .bottom
                    ) {
                        if let request, let size {
                            card(for: request, availableWidth: pane.width)
                                .frame(width: size.width, height: size.height)
                        }
                    }
            }
            .task(id: measured) {
                guard let measured else {
                    settled = nil
                    return
                }
                try? await Task.sleep(for: Self.settleDelay)
                guard !Task.isCancelled else { return }
                settled = measured
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func card(for request: TranscriptHoverRequest, availableWidth: CGFloat) -> some View {
        switch request.card {
        case .file(let attachment, let worktree):
            AttachmentCard(
                attachment: attachment, worktree: worktree, availableWidth: availableWidth
            )
        case .instructions(_, let body):
            InstructionsCard(text: body, availableWidth: availableWidth)
        case .row(let title, let detail, let isCode):
            ToolRowCard(
                title: title, detail: detail, isCode: isCode, availableWidth: availableWidth
            )
        }
    }

    private func anchor(for request: TranscriptHoverRequest?, in pane: CGRect) -> CGRect {
        guard let request else {
            return CGRect(x: pane.width / 2, y: pane.height / 2, width: 0, height: 0)
        }
        return request.frame.offsetBy(dx: -pane.minX, dy: -pane.minY)
    }
}
