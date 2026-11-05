import Core
import SwiftUI

struct ProfileSheet: View {
    let request: ProfileSheetRequest

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ProfileDraft
    @State private var isConfirmingDelete = false

    init(request: ProfileSheetRequest, profiles: [Profile]) {
        self.request = request
        switch request {
        case .new: _draft = State(initialValue: .new(among: profiles))
        case .edit(let profile): _draft = State(initialValue: ProfileDraft(editing: profile))
        }
    }

    var body: some View {
        ProfileSheetBody(
            draft: $draft,
            isNew: editing == nil,
            deletionRefusal: deletionRefusal,
            onDelete: { isConfirmingDelete = true },
            onCancel: { dismiss() },
            onSave: save
        )
        .confirmationDialog(
            "Delete \(editing?.name ?? "")?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This profile has no projects, so nothing else changes.")
        }
    }

    private var editing: Profile? {
        if case .edit(let profile) = request { return profile }
        return nil
    }

    private var deletionRefusal: String? {
        guard let editing else { return nil }
        return ProfileDeletionRefused.refusal(
            for: editing.id,
            projectCount: ProfileScope.repos(app.repos, in: editing.id).count
        )?.sentence
    }

    private func save() {
        guard draft.canSave else { return }
        let saved = draft
        let name = saved.savedName
        Task {
            if let editing {
                await app.updateProfile(editing.id) { profile in
                    profile.name = name
                    profile.colour = saved.colour
                    profile.symbol = saved.symbol
                }
            } else {
                await app.createProfile(name: name, colour: saved.colour, symbol: saved.symbol)
            }
        }
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        Task { await app.deleteProfile(editing.id) }
        dismiss()
    }
}

struct ProfileSheetBody: View {
    @Binding var draft: ProfileDraft
    var isNew: Bool
    var deletionRefusal: String?
    var onDelete: () -> Void
    var onCancel: () -> Void
    var onSave: () -> Void

    static let width: CGFloat = 440
    static let newHeight: CGFloat = 436
    static let editHeight: CGFloat = 500

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section(isNew ? "New Profile" : "Profile Settings") {
                    TextField(text: $draft.name, prompt: Text("Required")) {
                        Text("Name")
                        if let problem = draft.nameProblem {
                            Text(problem)
                        }
                    }
                }

                Section("Colour") {
                    ProfileColourGrid(selection: $draft.colour)
                }

                Section("Icon") {
                    ProfileSymbolGrid(selection: $draft.symbol, colour: draft.colour)
                }

                if !isNew {
                    deleteSection
                }
            }
            .settingsForm()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.canSave)
                    .help(draft.nameProblem ?? "")
            }
            .padding(Metrics.gutter)
        }
        .frame(width: Self.width, height: isNew ? Self.newHeight : Self.editHeight)
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Profile", role: .destructive, action: onDelete)
                .disabled(deletionRefusal != nil)
        } footer: {
            if let deletionRefusal {
                Text(deletionRefusal)
                    .settingsFootnote()
            }
        }
    }
}

struct ProfileColourGrid: View {
    @Binding var selection: String

    private static let size: CGFloat = 22

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: Accent.all.count)) {
            ForEach(Accent.all, id: \.self) { hex in
                swatch(hex)
            }
        }
    }

    private func swatch(_ hex: String) -> some View {
        let isSelected = selection == hex
        let name = ProfileChoices.colourName(hex)

        return Button {
            selection = hex
        } label: {
            Circle()
                .fill(Color(hexString: hex))
                .frame(width: Self.size, height: Self.size)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(Typo.captionEmphasis)
                            .foregroundStyle(.white)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel("Colour \(name)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct ProfileSymbolGrid: View {
    @Binding var selection: String
    var colour: String

    private static let size: CGFloat = 28
    private static let columns = 8

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: Self.columns)) {
            ForEach(ProfileChoices.symbols) { symbol in
                cell(symbol)
            }
        }
    }

    private func cell(_ symbol: ProfileChoices.Symbol) -> some View {
        let isSelected = selection == symbol.name

        return Button {
            selection = symbol.name
        } label: {
            Image(systemName: symbol.name)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Palette.textSecondary))
                .frame(width: Self.size, height: Self.size)
                .background {
                    if isSelected {
                        Circle().fill(Color(hexString: colour))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(symbol.label)
        .accessibilityLabel("Icon \(symbol.label)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
