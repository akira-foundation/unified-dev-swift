import SwiftUI
import AppKit
import Core

struct CreateWorkspaceView: View {
    var initialRepo: Repo?

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var repoID: RepoID?
    @State private var prompt = ""
    @State private var caret = 0
    @State private var isFocused = false
    @State private var contentHeight = ComposerTextEditor.lineHeight

    @State private var controls = ComposerControls()

    @State private var baseBranch = ""
    @State private var branches: [String] = []
    @State private var remoteBranches: [String] = []

    @State private var checkout: WorkspaceCheckout?
    @State private var checkoutOptions = WorkspaceCheckoutOptions()
    @State private var isLoadingCheckouts = false
    @State private var reference = ""
    @State private var isEnteringReference = false
    @FocusState private var isReferenceFocused: Bool
    @State private var referenceProblem: String?
    @State private var heldProblem: String?
    @State private var isResolvingReference = false
    @State private var branchPrefix: String?
    @State private var hasSetupScript = false
    @State private var runSetupScript = true
    @State private var isLoading = false

    @State private var isNamingAvailable = false

    @State private var draftID = PromptAttachments.newShortID()

    @State private var selectedMode: WorkspaceStartMode = .chat
    @State private var usesCLIChat = false
    @State private var loadedChatPreference = false

    @State private var typedName = ""
    @FocusState private var isNameFocused: Bool

    private static let width: CGFloat = 760
    private static let minEditorLines: CGFloat = 5

    private var repo: Repo? { app.repos.first { $0.id == repoID } }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var spokenPrompt: String {
        AttachmentDraft.withoutAttachments(prompt, paths: attachedPaths)
    }

    private var attachedPaths: [String] {
        PromptAttachmentStore.shared.attachments(for: draftID).map(\.path)
    }

    private var mode: WorkspaceStartMode {
        selectedMode == .chat
            ? WorkspaceStartMode.chat(usesCLI: usesCLIChat, agent: controls.agentKind) : selectedMode
    }

    private var task: String {
        mode.runsAnAgent ? spokenPrompt : typedName
    }

    private var canCreate: Bool {
        WorkspaceStartPlan.canStart(
            hasProject: repo != nil,
            prompt: task,
            hasCheckout: checkout != nil,
            isChatWorkspace: mode.runsAnAgent,
            isBusy: app.isCreatingWorkspace || isLoading
        )
    }

    private var consequence: some View {
        Text("Creates a separate copy of the project on this Mac, on its own branch.")
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, Metrics.gutter)
    }

    private var offersName: Bool { checkout == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if app.repos.isEmpty {
                noProjects
                    .padding(Metrics.gutter)
            } else {
                composer
                if hasSetupScript {
                    WorkspaceSetupOption(isEnabled: $runSetupScript)
                        .disabled(isLoading)
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.bottom, Metrics.spacingWide)
                }
                consequence
            }
        }
        .frame(width: Self.width)
        .background(Palette.surface)
        .task(id: repoID) { await load() }
        .task {
            guard CreateWorkspaceOpening.shared.consumePullRequestAsk() else { return }
            raisePullRequestBox()
        }
        .onChange(of: CreateWorkspaceOpening.shared.wantsPullRequest) { _, _ in
            guard CreateWorkspaceOpening.shared.consumePullRequestAsk() else { return }
            raisePullRequestBox()
        }
        .task(id: repoID) { await loadCheckouts() }
        .task(id: prefetchTarget) { await WorkspaceStartContext.prefetch(prefetchTarget) }
        .onDisappear(perform: discardDraft)
    }

    private var header: some View {
        HStack(spacing: Metrics.spacingSmall) {
            projectControl

            if repo != nil {
                sourceControl
            }

            Spacer(minLength: 0)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Loading branches")
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, Metrics.inset)
    }

    @ViewBuilder
    private var projectControl: some View {
        let label = ComposerControlLabel(
            text: repo?.name ?? "Choose a project",
            tint: Palette.textPrimary,
            showsMenuIndicator: app.repos.count > 1
        ) {
            RepoIcon(repo: repo, size: Metrics.repoIconSmall)
        }

        if app.repos.count > 1 {
            Menu {
                Picker("Project", selection: Binding(
                    get: { repoID ?? RepoID("") },
                    set: { repoID = $0.rawValue.isEmpty ? nil : $0 }
                )) {
                    ForEach(ProjectMenuGroup.grouped(app.repos)) { group in
                        Section(group.title) {
                            ForEach(group.repos) { candidate in
                                Label {
                                    Text(candidate.name)
                                } icon: {
                                    if let mark = RepoIconImage.of(candidate) {
                                        Image(nsImage: mark).renderingMode(.original)
                                    }
                                }
                                .tag(candidate.id)
                            }
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(.glass)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Choose the project")
            .accessibilityLabel("Project")
            .accessibilityValue(repo?.name ?? "")
        } else {
            label
        }
    }

    private var sourceControl: some View {
        WorkspaceSourcePicker(
            offering: offering,
            checkout: checkout,
            baseBranch: baseBranch.isEmpty ? (repo?.defaultBranch ?? "") : baseBranch,
            unavailable: pullRequestUnavailable,
            onPick: pick(_:)
        )
    }

    private var pullRequestUnavailable: String? {
        guard checkoutOptions.pullRequests.isEmpty else { return nil }
        if isLoadingCheckouts { return "Loading…" }
        switch checkoutOptions.access {
        case .notInstalled: return "Install the GitHub CLI to list pull requests"
        case .signedOut: return "Sign in with gh to list pull requests"
        case .ready: return checkoutOptions.failure ?? "No open pull requests"
        }
    }

    private var referenceField: some View {
        HStack(spacing: Metrics.spacingSmall) {
            TextField("Pull request number or URL", text: $reference)
                .textFieldStyle(.roundedBorder)
                .font(Typo.body)
                .focused($isReferenceFocused)
                .onSubmit { resolveReference(reference) }
                .disabled(isResolvingReference)

            if isResolvingReference {
                ProgressView().controlSize(.small)
            } else {
                Button("Open") { resolveReference(reference) }
                    .disabled(reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Button("Cancel", role: .cancel) {
                isEnteringReference = false
                reference = ""
                referenceProblem = nil
            }
            .buttonStyle(.glass)
            .font(Typo.caption)
            .foregroundStyle(Palette.textTertiary)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: Metrics.gutter) {
            modePicker

            if isEnteringReference {
                referenceField
            }

            if let referenceProblem {
                Text(referenceProblem)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.negative)
            }

            if let heldProblem {
                Text(heldProblem)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.negative)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let carryOn {
                HStack(spacing: Metrics.spacingSmall) {
                    Text(carryOn.sentence)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Button(carryOn.action) { pick(carryOn.source) }
                        .linkButton()
                        .font(Typo.caption)
                }
            }

            Text(heading)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            switch mode {
            case .chat, .claudeCLI, .codexCLI: chatBox
            case .terminal, .browser: nameBox
            }

            statusRow
        }
        .padding(Metrics.gutter)
    }

    private var modePicker: some View {
        Picker("Start with", selection: modeBinding) {
            Text("Chat").tag(WorkspaceStartMode.chat)
            Text("Terminal").tag(WorkspaceStartMode.terminal)
            Text("Browser").tag(WorkspaceStartMode.browser)
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .tint(Palette.controlAccent)
        .help(defaultCLIMode == nil
              ? "CLI chat supports Claude and Codex. Choose either as your default agent to use it."
              : "Chat and CLI chat use your default agent configuration")
    }

    private var defaultCLIMode: WorkspaceStartMode? {
        switch controls.agentKind {
        case .claudeCode: .claudeCLI
        case .codex: .codexCLI
        case .grok, .cursor, .openCode: nil
        }
    }

    private var modeBinding: Binding<WorkspaceStartMode> {
        Binding(
            get: { selectedMode },
            set: { chosen in
                guard chosen != selectedMode else { return }
                switch chosen {
                case .terminal, .browser:
                    typedName = WorkspaceStartPlan.carriedName(
                        prompt: spokenPrompt, currentName: typedName
                    )
                case .chat, .claudeCLI, .codexCLI:
                    prompt = WorkspaceStartPlan.carriedPrompt(
                        name: typedName, currentPrompt: prompt
                    )
                    caret = (prompt as NSString).length
                }
                selectedMode = chosen
                focusTheBox()
            }
        )
    }

    private var chatBox: some View {
        ComposerPrompt(
            text: $prompt,
            caret: $caret,
            isFocused: $isFocused,
            mentionRoot: repo?.path ?? NSHomeDirectory(),
            attachmentRoot: stagingDirectory,
            attachmentKey: draftID,
            placeholder: "Describe the task, @mention files, run /commands",
            editorHeight: editorHeight,
            onContentHeightChange: { contentHeight = $0 },
            onKey: handle(key:),
            onOpenAttachment: open(attachment:)
        ) { actions in
            ComposerFooterView(
                controls: controls,
                onChange: { controls = $0 },
                canSend: canCreate,
                intent: .create,
                adaptsToWidth: false,
                project: repo?.path,
                onAttach: actions.attach,
                onQuickPrompt: actions.insert,
                onSend: create,
                usesCLIChat: Binding(
                    get: { usesCLIChat && defaultCLIMode != nil },
                    set: { usesCLIChat = $0 }
                ),
                supportsCLIChat: defaultCLIMode != nil
            )
        }
    }

    private var nameBox: some View {
        VStack(alignment: .leading, spacing: Metrics.spacingWide) {
            if offersName {
                TextField("Optional", text: $typedName)
                    .textFieldStyle(.roundedBorder)
                    .font(Typo.body)
                    .focused($isNameFocused)
                    .onSubmit(create)
                    .accessibilityLabel("Workspace name")
            }

            Text(startNote)
                .font(Typo.caption)
                .foregroundStyle(Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let sentence = attachmentNote {
                Label(sentence, systemImage: "paperclip")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Metrics.spacing) {
                Spacer(minLength: 0)
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                ComposerSendButton(intent: .create, canSend: canCreate, onSend: create)
            }
        }
        .composerBox(isFocused: .constant(false))
    }

    private var attachmentNote: String? {
        let count = attachedPaths.count
        guard count > 0 else { return nil }
        return count == 1
            ? "The file you attached is copied into the worktree."
            : "The \(count) files you attached are copied into the worktree."
    }

    private var startNote: String {
        WorkspaceStartPlan.startNote(mode: mode, hasCheckout: !offersName, name: typedName)
    }

    private var heading: String {
        guard mode.runsAnAgent else {
            let opened = mode.label.lowercased()
            switch checkout {
            case .pullRequest(let request): return "Open #\(request.number) in a \(opened)"
            case .branch(let branch): return "Open \(branch.name) in a \(opened)"
            case .none: return "Workspace name"
            }
        }
        switch checkout {
        case .pullRequest(let request): return "What should happen to #\(request.number)?"
        case .branch(let branch): return "What should happen on \(branch.name)?"
        case .none: return "What do you want to work on?"
        }
    }

    private var editorHeight: CGFloat {
        max(contentHeight, ComposerTextEditor.lineHeight * Self.minEditorLines)
    }

    private var statusRow: some View {
        HStack(spacing: Metrics.spacingWide) {
            if mode.cliAgentKind != nil {
                Text("Opens in a terminal using your default agent configuration")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
            } else {
                hint
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var hint: some View {
        if let checkout {
            HStack(spacing: Metrics.spacingSmall) {
                Chip(
                    text: "\(checkout.preferredLocalBranch) → \(checkout.baseBranch(default: repo?.defaultBranch ?? "main"))",
                    systemImage: "arrow.triangle.pull",
                    monospaced: true
                )
                .lineLimit(1)

                if let sentence = checkoutNote {
                    Text(sentence)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textTertiary)
                        .lineLimit(1)
                }
            }
        } else if willBeNamedByModel {
            EmptyView()
        } else if task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if mode.runsAnAgent {
                Text("The branch is named from what you write")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
        } else {
            Chip(text: branchPreview, systemImage: "arrow.triangle.branch", monospaced: true)
                .lineLimit(1)
        }
    }

    private var checkoutNote: String? {
        guard let checkout else { return nil }
        if let sentence = WorkspaceCheckoutPlan.warning(for: checkout) { return sentence }
        return holder(of: checkout)?.note
    }

    private var noProjects: some View {
        ContentUnavailableView {
            Label("No projects yet", systemImage: "folder.badge.plus")
        } description: {
            Text("Add a git repository before starting a workspace.")
        } actions: {
            Button("Choose a folder", systemImage: "folder", action: addProject)
                .buttonStyle(.borderedProminent)
                .tint(Palette.controlAccent)
        }
    }

    private var stagingDirectory: String {
        AttachmentStaging.directory(draftID: draftID)
    }

    private var branchOptions: [String] {
        guard let repo else { return branches }
        return WorkspaceStartContext.baseBranchOptions(
            local: branches, remote: remoteBranches, defaultBranch: repo.defaultBranch
        )
    }

    private var prefetchTarget: BaseBranchPrefetch? {
        BaseBranchPrefetch.target(
            repoPath: repo?.path, baseBranch: baseBranch, opensCheckout: checkout != nil
        )
    }

    private var offering: WorkspaceSourceOffering {
        WorkspaceSourceOffering(
            pullRequests: checkoutOptions.pullRequests,
            branches: checkoutOptions.branches,
            baseBranches: branchOptions
        )
    }

    private var carryOn: WorkspaceCarryOnOffer? {
        guard checkout == nil else { return nil }
        return offering.carryOn(from: baseBranch, holders: checkoutOptions.holders)
    }

    private var willBeNamedByModel: Bool {
        WorkspaceNaming.shouldName(
            userSuppliedName: nil,
            prompt: spokenPrompt.isEmpty ? "a task" : spokenPrompt,
            isChatWorkspace: mode.runsAnAgent,
            isEnabled: WorkspaceNamingPreferences().isEnabled,
            isAgentAvailable: isNamingAvailable
        )
    }

    private var branchPreview: String {
        Git.branchStem(prompt: task, prefix: branchPrefix)
    }

    private func handle(key: ComposerKey) -> Bool {
        switch key {
        case .returnKey, .commandReturn:
            create()
            return true
        case .escape:
            dismiss()
            return true
        case .up, .down, .tab:
            return false
        }
    }

    private func load() async {
        if repoID == nil {
            repoID = initialRepo?.id
                ?? app.selectedWorkspace.flatMap { app.repo(for: $0) }?.id
                ?? app.repos.first?.id
            return
        }
        guard let repo else { return }

        heldProblem = nil
        runSetupScript = true
        hasSetupScript = false

        focusTheBox()
        isLoading = true

        let path = repo.path
        var appDefaults = AppDefaults()
        if let store = app.store {
            appDefaults = await AppDefaults.load(from: store)
        }

        if !loadedChatPreference {
            usesCLIChat = appDefaults.terminalChat
            loadedChatPreference = true
        }
        let context = await WorkspaceStartContext.load(repoPath: path)

        guard !Task.isCancelled else { return }
        isLoading = false

        branches = context.branches
        remoteBranches = context.remoteBranches
        branchPrefix = context.settings.branchPrefix
        hasSetupScript = !(context.settings.setupScript ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        isNamingAvailable = context.isNamingAvailable
        controls = ComposerControls(
            defaults: ComposerDefaults.resolve(
                repo: context.settings,
                app: appDefaults,
                models: ComposerModelCatalog.shared.models
            ),
            isFastMode: appDefaults.fastMode,
            outputStyle: appDefaults.outputStyle,
            codexContextWindow: appDefaults.codexContextWindow
        )

        baseBranch = WorkspaceStartContext.resolvedBaseBranch(
            current: baseBranch,
            branches: branchOptions,
            defaultBranch: repo.defaultBranch
        )
    }

    private func pick(_ source: WorkspaceSource) {
        heldProblem = nil
        switch source {
        case .newBranch(let ref):
            checkout = nil
            baseBranch = ref
            focusTheBox()
        case .existingBranch(let branch):
            offer(.branch(branch))
        case .pullRequest(.listed(let request)):
            offer(.pullRequest(request))
        case .pullRequest(.typed(_, let text)):
            reference = text
            referenceProblem = nil
            isEnteringReference = true
            resolveReference(text)
        }
    }

    private func offer(_ chosen: WorkspaceCheckout) {
        guard let holder = holder(of: chosen) else {
            choose(chosen)
            return
        }
        let branch = WorkspaceCheckoutPlan.localBranch(for: chosen, taken: Set(branches))
        if holder.isAppWorkspace, let repo, let held = WorkspaceCheckoutPlan.workspaceHolding(
            branch: branch, in: repo.id, among: app.workspaces
        ) {
            app.selection = .workspace(held.id)
            dismiss()
            return
        }
        heldProblem = holder.refusal(branch: branch)
    }

    private func holder(of chosen: WorkspaceCheckout) -> BranchHolder? {
        checkoutOptions.holders[
            WorkspaceCheckoutPlan.localBranch(for: chosen, taken: Set(branches))
        ]
    }

    private func choose(_ chosen: WorkspaceCheckout) {
        checkout = chosen
        isEnteringReference = false
        referenceProblem = nil
        heldProblem = nil
        reference = ""
        focusTheBox()
    }

    private func raisePullRequestBox() {
        isEnteringReference = true
        isReferenceFocused = true
    }

    private func focusTheBox() {
        isFocused = mode.runsAnAgent
        isNameFocused = !mode.runsAnAgent && offersName
    }

    private func resolveReference(_ text: String) {
        guard let repo, !isResolvingReference else { return }
        let path = repo.path
        isResolvingReference = true
        referenceProblem = nil
        Task {
            let resolution = await WorkspaceCheckoutResolver.resolve(text, repoPath: path)
            isResolvingReference = false
            switch resolution {
            case .checkout(let resolved): offer(resolved)
            case .failure(let sentence): referenceProblem = sentence
            }
        }
    }

    private func loadCheckouts() async {
        guard let repo else { return }
        isLoadingCheckouts = true
        let options = await WorkspaceCheckoutOptions.load(
            repoPath: repo.path,
            repoID: repo.id,
            defaultBranch: repo.defaultBranch,
            workspaces: app.workspaces
        )
        guard !Task.isCancelled else { return }
        isLoadingCheckouts = false
        checkoutOptions = options
    }

    private func addProject() {
        Task { await app.addProjectByAsking() }
    }

    private func open(attachment: PromptAttachment) {
        NSWorkspace.shared.open(attachment.url(in: stagingDirectory))
    }

    private func create() {
        guard let repo, canCreate else { return }

        let chosen = mode
        let text = WorkspaceStartAttachments.handover(
            isChatWorkspace: chosen.runsAnAgent, draft: prompt, name: typedName
        )
        let base = baseBranch.isEmpty ? repo.defaultBranch : baseBranch
        let source = checkout
        let chosenControls = controls
        let shouldRunSetup = runSetupScript

        let directory = stagingDirectory
        let handedOver = draftID
        let ready = PromptAttachmentStore.shared.attachments(for: handedOver).filter {
            FileManager.default.fileExists(atPath: $0.url(in: directory).path)
        }
        let staged = StagedAttachments(directory: directory, attachments: ready)
        PromptAttachmentStore.shared.clear(sessionID: handedOver)
        draftID = PromptAttachments.newShortID()

        dismiss()

        openWindow(id: UnifiedDevApp.mainWindowID)

        Task {
            await app.createWorkspace(
                in: repo,
                prompt: text,
                baseBranch: base,
                opensWith: chosen,
                controls: chosenControls,
                staged: staged,
                checkout: source,
                runSetupScript: shouldRunSetup
            )
            AttachmentStaging.discard(draftID: handedOver)
        }
    }

    private func discardDraft() {
        let id = draftID
        PromptAttachmentStore.shared.clear(sessionID: id)
        Task.detached(priority: .utility) {
            AttachmentStaging.discard(draftID: id)
        }
    }
}
