import SwiftUI
import Core

struct CanvasFrameCreation: View {
    let add: (CanvasFramePreset) -> Void

    var body: some View {
        Menu {
            ForEach(CanvasFramePreset.allCases, id: \.self) { preset in
                Button(preset.title) { add(preset) }
            }
        } label: {
            Image(systemName: "rectangle.badge.plus")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 34, height: 28)
        .help("Add Frame")
        .accessibilityLabel("Add Frame")
    }
}
