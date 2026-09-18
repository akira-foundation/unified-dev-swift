import SwiftUI
import Core

struct StartProjectView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    private enum Phase: Equatable {
        case naming
        case working(RepositoryStartStep)
        case failed(NewProjectFailure)
    }

    @State private var typed = ""
    @State private var facts = NewProjectFacts()
    @State private var contents: FolderContents?
    @State private var phase: Phase = .naming
    @State private var defaultLocation = ""
    @State private var projectsThere = 0
    @State private var searchLocations: [String] = []
    @State private var isLocationLoaded = false
    @State private var completions: [String] = []
    @State private var selectedCompletion: Int?
    @State private var acceptedCompletion: String?
    @State private var branch = "main"
    @State private var identityProblem: String?
    @State private var createTask: Task<Void, Never>?
    @State private var isStepSlow = false
    @State private var isFinishing = false
    @FocusState private var isFieldFocused: Bool

    private static let width: CGFloat = 560
    private static let inspectionDelay = Duration.milliseconds(150)
    private static let blockMinHeight: CGFloat = 52
    private static let excludedShown = 8

    private var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    private var verdict: ProjectTargetVerdict { ProjectTargetVerdict.of(facts) }

    private var hasTyped: Bool {
        !typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var consequence: ProjectConsequence {
        guard isLocationLoaded else {
            return ProjectConsequence(detail: "Loading project folders…", tone: .waiting)
        }
        guard hasTyped else {
            return .opening(location: defaultLocation, projectsThere: projectsThere, home: home)
        }
        return .of(verdict, path: facts.path, home: home, branch: branch, contents: contents)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()

            VStack(alignment: .leading, spacing: Metrics.gutter) {
                switch phase {
                case .naming: form
                case .working(let step): working(step)
                case .failed(let failure): failed(failure)
                }
            }
            .padding(Metrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)

            Hairline()
            footer
        }
        .frame(width: Self.width)
        .background(Palette.surface)
        .navigationTitle(title)
        .task {
            let preferences: DirectoryPreferences
            if let store = app.store { preferences = await DirectoryPreferences.load(from: store) } else {
                preferences = DirectoryPreferences()
            }
            let paths = app.repos.map(\.path)
            defaultLocation = preferences.projectLocation(projectPaths: paths, home: home)
            searchLocations = preferences.searchLocations(projectPaths: paths, home: home)
            projectsThere = NewProjectPlan.projectsIn(defaultLocation, projectPaths: paths)
            isLocationLoaded = true
            isFieldFocused = true
            branch = await NewProjectStarter.plannedBranch()
            identityProblem = await RepositoryStarter.identityProblem(at: home)
        }
        .task(id: Draft(typed: typed, location: defaultLocation)) {
            try? await Task.sleep(for: Self.inspectionDelay)
            guard !Task.isCancelled else { return }
            let line = typed
            let location = defaultLocation
            let found = await Task.detached {
                NewProjectStarter.inspect(typed: line, defaultLocation: location)
            }.value
            guard !Task.isCancelled else { return }
            facts = found
        }
        .task(id: typed + searchLocations.joined(separator: "\n")) {
            completions = []
            selectedCompletion = nil
            guard typed != acceptedCompletion else { return }
            try? await Task.sleep(for: Self.inspectionDelay)
            guard !Task.isCancelled else { return }
            let line = typed
            let locations = searchLocations
            let userHome = home
            let matches = await Task.detached {
                ProjectCompletion.matches(line, locations: locations, home: userHome)
            }.value
            guard !Task.isCancelled else { return }
            completions = matches
        }
        .task(id: pathToScan) {
            contents = nil
            guard let path = pathToScan else { return }
            let found = await Task.detached { RepositoryStarter.scan(path) }.value
            guard !Task.isCancelled else { return }
            contents = found
        }
        .onDisappear {
            createTask?.cancel()
            createTask = nil
            guard !isFinishing, case .working = phase else { return }
            let target = facts.path
            let made = !facts.targetExists
            Task { await NewProjectStarter.discard(at: target, folderWasCreated: made) }
        }
    }

    private struct Draft: Equatable {
        var typed: String
        var location: String
    }

    private var pathToScan: String? {
        guard case .track = verdict, !facts.path.isEmpty else { return nil }
        return facts.path
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.spacingWide) {
            Image(systemName: "folder.badge.plus")
                .font(Typo.bodyEmphasis)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)

            Text("Create a folder on this Mac and add it to the sidebar.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.inset)
    }

    private var title: String {
        switch phase {
        case .naming: "Start a project"
        case .working: "Setting up \(folderName)"
        case .failed(let failure): failure.title
        }
    }

    private var folderName: String {
        let name = (facts.path as NSString).lastPathComponent
        return name.isEmpty ? "the project" : name
    }

    @ViewBuilder
    private var form: some View {
        HStack(spacing: Metrics.spacingWide) {
            TextField("Name it, or point at a folder", text: $typed)
                .textFieldStyle(.roundedBorder)
                .font(Typo.body)
                .focused($isFieldFocused)
                .disabled(!isLocationLoaded)
                .onKeyPress(.return) {
                    guard let selectedCompletion else { return .ignored }
                    acceptCompletion(selectedCompletion)
                    return .handled
                }
                .onSubmit {
                    if let selectedCompletion { acceptCompletion(selectedCompletion) } else { start() }
                }
                .onKeyPress(.downArrow) {
                    guard !completions.isEmpty else { return .ignored }
                    selectedCompletion = min((selectedCompletion ?? -1) + 1, completions.count - 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !completions.isEmpty else { return .ignored }
                    selectedCompletion = max((selectedCompletion ?? 1) - 1, 0)
                    return .handled
                }
                .onKeyPress(.tab) {
                    guard !completions.isEmpty else { return .ignored }
                    acceptCompletion(selectedCompletion ?? 0)
                    return .handled
                }
                .onKeyPress(.escape) {
                    guard !completions.isEmpty else { return .ignored }
                    completions = []
                    selectedCompletion = nil
                    return .handled
                }
            Button("Choose\u{2026}", action: chooseFolder)
        }

        if !completions.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.spacingSmall) {
                ForEach(Array(completions.enumerated()), id: \.element) { index, path in
                    Button { acceptCompletion(index) } label: {
                        HStack {
                            Image(systemName: "folder")
                            Text((path as NSString).lastPathComponent)
                            Spacer()
                            Text(NewProjectPlan.display(path, home: home))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                        .padding(Metrics.spacingSmall)
                        .background(selectedCompletion == index ? Palette.controlAccent.opacity(0.15) : .clear)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(NewProjectPlan.display(path, home: home))
                }
            }
        }

        if let identityProblem, verdict.makesACommit {
            Callout(text: identityProblem, symbol: "exclamationmark.triangle.fill", tone: .warning)
        }

        block
    }

    private var block: some View {
        let said = consequence
        return HStack(alignment: .top, spacing: Metrics.spacingWide) {
            Image(systemName: symbol(for: said.tone))
                .font(Typo.caption)
                .foregroundStyle(ink(for: said.tone))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Metrics.spacingTight) {
                if let lead = said.lead {
                    Text(lead)
                        .font(Typo.codeSmall)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                Text(said.detail)
                    .font(Typo.caption)
                    .foregroundStyle(
                        said.tone == .waiting ? Palette.textTertiary : Palette.textSecondary
                    )
                    .fixedSize(horizontal: false, vertical: true)

                if !said.excluded.isEmpty { excluded(said.excluded) }

                if let alternative = said.alternative {
                    Button("Use \(NewProjectPlan.display(alternative, home: home))") {
                        typed = NewProjectPlan.display(alternative, home: home)
                    }
                    .controlSize(.small)
                    .padding(.top, Metrics.spacingTight)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Metrics.inset)
        .frame(maxWidth: .infinity, minHeight: Self.blockMinHeight, alignment: .topLeading)
        .background(Palette.surfaceSunken, in: RoundedRectangle(cornerRadius: Metrics.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner)
                .strokeBorder(said.tone == .refusal ? Palette.negative.opacity(0.35) : .clear)
        )
    }

    private func excluded(_ paths: [ExcludedPath]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.spacingTight) {
            ForEach(paths.prefix(Self.excludedShown)) { item in
                HStack(spacing: Metrics.spacingSmall) {
                    Image(systemName: item.reason == .sensitive
                        ? "key.fill" : "folder.badge.gearshape")
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textTertiary)
                    Text(item.path)
                        .font(Typo.codeTiny)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            if paths.count > Self.excludedShown {
                Text("and \(paths.count - Self.excludedShown) more")
                    .font(Typo.codeTiny)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.top, Metrics.spacingTight)
    }

    private func symbol(for tone: ProjectConsequenceTone) -> String {
        switch tone {
        case .waiting: "folder"
        case .going: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .refusal: "exclamationmark.circle.fill"
        }
    }

    private func ink(for tone: ProjectConsequenceTone) -> Color {
        switch tone {
        case .waiting: Palette.textTertiary
        case .going: Palette.accent(beside: [.warning, .negative])
        case .caution: Palette.warning
        case .refusal: Palette.negative
        }
    }

    private func working(_ step: RepositoryStartStep) -> some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            VStack(alignment: .leading, spacing: Metrics.spacing) {
                ForEach(RepositoryStartStep.steps(for: .local), id: \.self) { candidate in
                    HStack(spacing: Metrics.spacingWide) {
                        switch candidate {
                        case ..<step:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Palette.positive)
                                .accessibilityHidden(true)
                        case step:
                            ProgressView().controlSize(.small)
                                .accessibilityHidden(true)
                        default:
                            Image(systemName: "circle")
                                .foregroundStyle(Palette.textTertiary)
                                .accessibilityHidden(true)
                        }
                        Text(candidate.label)
                            .font(Typo.label)
                            .foregroundStyle(
                                candidate == step ? Palette.textPrimary : Palette.textSecondary
                            )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(candidate.label)
                    .accessibilityValue(
                        candidate < step ? "Done" : candidate == step ? "Running" : "Not started"
                    )
                }
            }

            if isStepSlow {
                Callout(text: step.slowNotice, symbol: "clock.badge.exclamationmark", tone: .warning)
            }
        }
        .task(id: step) {
            isStepSlow = false
            try? await Task.sleep(for: step.patience)
            guard !Task.isCancelled else { return }
            isStepSlow = true
        }
    }

    private func failed(_ failure: NewProjectFailure) -> some View {
        Callout(text: failure.message, symbol: "exclamationmark.triangle.fill", tone: .negative)
    }

    private var footer: some View {
        HStack(spacing: Metrics.spacingWide) {
            Spacer(minLength: 0)

            switch phase {
            case .naming:
                Button("Cancel", role: .cancel) { finish(nil) }
                    .keyboardShortcut(.cancelAction)
                Button(verdict.buttonTitle, action: start)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.controlAccent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canStart)

            case .working:
                Button("Stop", role: .cancel, action: stop)
                    .keyboardShortcut(.cancelAction)

            case .failed:
                Button("Close", role: .cancel, action: discardAndClose)
                    .keyboardShortcut(.cancelAction)
                Button("Try again") { phase = .naming }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.controlAccent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.inset)
    }

    private var canStart: Bool {
        guard isLocationLoaded, hasTyped, verdict.isAllowed else { return false }
        return identityProblem == nil || !verdict.makesACommit
    }

    private func acceptCompletion(_ index: Int) {
        guard completions.indices.contains(index) else { return }
        let path = NewProjectPlan.display(completions[index], home: home)
        acceptedCompletion = path
        typed = path
        completions = []
        selectedCompletion = nil
    }

    private func chooseFolder() {
        let opening = facts.targetExists
            ? facts.path
            : (facts.nearestExistingAncestor.isEmpty
                ? defaultLocation
                : facts.nearestExistingAncestor)
        Task {
            guard let chosen = await ProjectFolderPicker.chooseTarget(startingAt: opening)
            else { return }
            typed = NewProjectPlan.display(chosen, home: home)
        }
    }

    private func start() {
        let current = NewProjectStarter.inspect(typed: typed, defaultLocation: defaultLocation)
        facts = current
        let decided = ProjectTargetVerdict.of(current)
        guard decided.isAllowed, !current.path.isEmpty else { return }
        guard identityProblem == nil || !decided.makesACommit else { return }

        if case .add(let root) = decided {
            finish(StartedProject(path: root, opensWorkspace: false))
            return
        }

        let target = current.path
        let opensWorkspace = decided.opensAWorkspace
        isStepSlow = false
        phase = .working(.initialise)

        createTask?.cancel()
        createTask = Task {
            do {
                let creation = try await NewProjectStarter.create(at: target) { step in
                    phase = .working(step)
                }
                guard !Task.isCancelled else { return }
                finish(StartedProject(path: creation.path, opensWorkspace: opensWorkspace))
            } catch let failure as NewProjectFailure {
                guard !Task.isCancelled else { return }
                phase = .failed(failure)
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(NewProjectFailure(
                    title: "Could not start the project",
                    message: RepositoryStarter.sentence(from: error),
                    folderWasCreated: false
                ))
            }
        }
    }

    private func stop() {
        createTask?.cancel()
        createTask = nil
        let target = facts.path
        Task {
            await NewProjectStarter.discard(at: target, folderWasCreated: !facts.targetExists)
            finish(nil)
        }
    }

    private func finish(_ started: StartedProject?) {
        isFinishing = true
        guard let started else { return dismiss() }
        Task {
            let repo = await app.addStartedProject(at: started.path)
            dismiss()
            openWindow(id: UnifiedDevApp.mainWindowID)
            guard started.opensWorkspace, let repo else { return }
            openWindow(id: CreateWorkspaceWindow.id, value: repo.id)
        }
    }

    private func discardAndClose() {
        guard case .failed(let failure) = phase else {
            finish(nil)
            return
        }
        let target = facts.path
        Task {
            await NewProjectStarter.discard(
                at: target, folderWasCreated: failure.folderWasCreated
            )
            finish(nil)
        }
    }
}

struct StartedProject: Equatable {
    var path: String
    var opensWorkspace: Bool
}
