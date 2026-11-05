import SwiftUI
import Core

struct CanvasFrameCreation: View {
    let add: (CanvasFramePreset) -> Void

    var body: some View {
        CanvasBarMenu(symbol: "rectangle.badge.plus") {
            ForEach(CanvasFramePreset.allCases, id: \.self) { preset in
                Button(preset.title) { add(preset) }
            }
        }
        .help("Add Frame")
        .accessibilityLabel("Add Frame")
    }
}
