import SwiftUI
import Core

struct MergeSplitButton: View {
    var method: GitHub.MergeMethod
    var fill: Color
    var canMerge: Bool
    var help: String?
    var choose: (GitHub.MergeMethod) -> Void
    var merge: () -> Void

    @Environment(\.isEnabled) private var isClusterEnabled

    private var isLive: Bool { isClusterEnabled && canMerge }

    var body: some View {
        styled
            .labelStyle(.titleAndIcon)
            .fixedSize()
        .id(method)
    }

    private var styled: some View {
        Menu {
            Picker("Merge method", selection: binding) {
                ForEach(MergeMethodChoice.offered, id: \.self) { offered in
                    Text(offered.label).tag(offered)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label(method.buttonLabel, systemImage: "arrow.triangle.merge")
        } primaryAction: {
            merge()
        }
        .menuStyle(.button)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .disabled(!canMerge)
        .help(help ?? "\(method.buttonLabel), or choose another method from the chevron")
        .fixedSize()
        .id(method)
    }

    private var binding: Binding<GitHub.MergeMethod> {
        Binding(get: { method }, set: { choose($0) })
    }
}
