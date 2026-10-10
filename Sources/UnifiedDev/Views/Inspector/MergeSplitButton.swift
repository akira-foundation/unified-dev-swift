import SwiftUI
import Core

struct MergeSplitButton: View {
    var label: String
    var method: GitHub.MergeMethod
    var canMerge: Bool
    var help: String?
    var choose: (GitHub.MergeMethod) -> Void
    var merge: () -> Void

    var body: some View {
        styled
            .labelStyle(.titleOnly)
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
            Text(label)
        } primaryAction: {
            merge()
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(!canMerge)
        .help(help ?? "\(method.buttonLabel), or choose another method from the chevron")
        .fixedSize()
        .id(method)
    }

    private var binding: Binding<GitHub.MergeMethod> {
        Binding(get: { method }, set: { choose($0) })
    }
}
