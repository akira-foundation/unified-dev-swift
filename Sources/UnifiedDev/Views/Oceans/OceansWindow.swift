import SwiftUI
import AppKit
import Core

struct OceansWindow: Scene {
    let model: AppModel

    static let id = "oceans"

    var body: some Scene {
        Window("Discovered Seas", id: Self.id) {
            OceansMapView()
                .environment(model)
                .windowRole(.reading)
        }
        .defaultSize(width: Self.openingSize.width, height: Self.openingSize.height)
        .defaultPosition(.center)
    }

    static let openingSize: (width: Double, height: Double) = {
        let screen = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        return SeaChartProjection.defaultWindowSize(
            screenWidth: screen.width, screenHeight: screen.height,
            margin: SeaChartView.margin, footerHeight: 38
        )
    }()
}

private struct OceansMapView: View {
    @Environment(AppModel.self) private var app

    @State private var discovered: [Ocean] = []
    @State private var waitingCount = 0
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            SeaChartView(
                discovered: discovered,
                showEmptyNotice: hasLoaded && discovered.isEmpty
            )
            footer
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(Palette.windowBackground)
        .task { await load() }
    }

    private var footer: some View {
        HStack {
            Text(summary)
                .font(Typo.label)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text("Pinch to zoom, scroll to pan, double click for the whole world")
                .font(Typo.label)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.spacingWide)
        .background(Palette.controlStrip)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: Metrics.hairline)
        }
    }

    private var summary: String {
        let found = discovered.count
        let foundPart = found == 1 ? "1 sea discovered." : "\(found) seas discovered."
        let waitingPart: String
        switch waitingCount {
        case 0: waitingPart = "None are left waiting."
        case 1: waitingPart = "1 is still waiting."
        default: waitingPart = "\(waitingCount) are still waiting."
        }
        return "\(foundPart) \(waitingPart)"
    }

    private func load() async {
        guard let store = app.store else { return }
        let all = (try? await store.oceans()) ?? []
        discovered = all
            .filter { $0.usedAt != nil }
            .sorted { ($0.usedAt ?? .distantPast, $0.slug) < ($1.usedAt ?? .distantPast, $1.slug) }
        waitingCount = (try? await store.unusedOceanCount()) ?? 0
        hasLoaded = true
    }
}
