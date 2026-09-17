import SwiftUI
import Core

struct QuickPromptFormDraft: Equatable {
    var editing: QuickPrompt?
    var name: String
    var symbol: String
    var text: String
    var sendsImmediately: Bool
    var opensNewChat: Bool

    init(editing: QuickPrompt? = nil, suggestedName: String = "") {
        self.editing = editing
        name = editing?.name ?? suggestedName
        symbol = editing.map { QuickPrompt.resolvedSymbol($0.symbol) } ?? QuickPrompt.defaultSymbol
        text = editing?.text ?? ""
        sendsImmediately = editing?.sendsImmediately ?? false
        opensNewChat = editing?.opensNewChat ?? false
    }

    var fields: QuickPrompt.Fields {
        QuickPrompt.Fields(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            sendsImmediately: sendsImmediately,
            opensNewChat: opensNewChat
        )
    }
}

struct QuickPromptForm: View {
    @Binding var draft: QuickPromptFormDraft
    var startsPickingMark = false
    var onCancel: @MainActor () -> Void
    var onSave: @MainActor (QuickPrompt.Fields) -> Void
    var onDelete: @MainActor () -> Void

    @State private var isPickingMark = false

    @FocusState private var isNameFocused: Bool

    private static let textHeight: CGFloat = 108
    private static let wellSize: CGFloat = 22
    private static let wellPoints: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.pane) {
            heading

            VStack(alignment: .leading, spacing: Metrics.spacingWide) {
                field("Name and icon") {
                    HStack(spacing: Metrics.spacing) {
                        well

                        TextField("Run the tests", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                            .font(Typo.body)
                            .focused($isNameFocused)
                            .accessibilityLabel("Quick prompt name")
                    }
                }
            }

            field("Text") {
                TextEditor(text: $draft.text)
                    .font(Typo.body)
                    .scrollContentBackground(.hidden)
                    .frame(height: Self.textHeight)
                    .background(
                        Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                            .strokeBorder(Palette.border, lineWidth: Metrics.outline)
                    }
                    .accessibilityLabel("Quick prompt text")
            }

            behaviour

            buttons
        }
        .padding(Metrics.pane)
        .focusedValue(\.isTypingProse, isNameFocused)
        .onAppear {
            isPickingMark = startsPickingMark
            isNameFocused = true
        }
        .onExitCommand { isPickingMark ? closePicker() : onCancel() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
            Text(draft.editing == nil ? "New quick prompt" : "Edit quick prompt")
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.textPrimary)

            Text(
                draft.editing == nil
                    ? "It is available in every workspace."
                    : "Changes apply everywhere. Nothing already sent is affected."
            )
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var well: some View {
        Button {
            isPickingMark.toggle()
        } label: {
            QuickPromptMarkView(
                stored: draft.symbol, points: Self.wellPoints, tint: Palette.textPrimary
            )
            .frame(width: Self.wellSize, height: Self.wellSize)
            .background(
                Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.cornerSmall)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                    .strokeBorder(
                        isPickingMark ? Palette.accent : Palette.border,
                        lineWidth: Metrics.outline
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isPickingMark,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            picker
        }
        .help("Choose an icon or an emoji")
        .accessibilityLabel("Quick prompt icon")
    }

    private var picker: some View {
        QuickPromptMarkPicker(
            selection: draft.symbol,
            onChoose: { mark in
                draft.symbol = mark.stored
                closePicker()
            },
            onClose: closePicker
        )
    }

    private var behaviour: some View {
        field("When you choose it") {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                toggle("Send it straight away", isOn: $draft.sendsImmediately)
                toggle("Open it in a new chat tab", isOn: $draft.opensNewChat)

                if let sentence = delivery.sentence {
                    Text(sentence)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var delivery: QuickPromptDelivery {
        QuickPromptDelivery(
            sendsImmediately: draft.sendsImmediately,
            opensNewChat: draft.opensNewChat
        )
    }

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Metrics.spacing) {
            Text(title)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture { isOn.wrappedValue.toggle() }

            Spacer(minLength: Metrics.spacing)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var buttons: some View {
        HStack(spacing: Metrics.spacingWide) {
            if draft.editing != nil {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete").foregroundStyle(Palette.negative)
                }
                .accessibilityLabel("Delete this quick prompt")
                Spacer(minLength: Metrics.spacing)
            } else {
                Spacer(minLength: Metrics.spacing)
            }

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button("Save") {
                onSave(draft.fields)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacing) {
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
            content()
        }
    }

    private func closePicker() {
        isPickingMark = false
        isNameFocused = true
    }
}
