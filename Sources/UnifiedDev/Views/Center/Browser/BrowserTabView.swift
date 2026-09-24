import SwiftUI
import Core

struct BrowserTabView: View {
    @Bindable var model: WorkspaceModel
    var tab: CenterTab
    var paneMenu: (@MainActor () -> NSMenu)?
    var siblings: [PaneContent] = []

    @State private var address = ""
    @FocusState private var isAddressFocused: Bool
    @FocusState private var isFindFocused: Bool

    @State private var isCapturing = false
    @State private var isSelectingRegion = false
    @State private var regionCapture: BrowserRegionCapture?
    @State private var viewportFrame: CGRect = .zero
    @State private var room = ComposerRoom()

    @Environment(AppModel.self) private var app

    @Environment(\.controlActiveState) private var activeState

    private var tabs: CenterTabStore { .shared }
    private var session: BrowserSession { tabs.browser(for: tab, root: model.workspace.path) }

    private var isRingVisible: Bool { isAddressFocused && activeState.showsFocusRing }

    var body: some View {
        let session = self.session

        VStack(spacing: 0) {
            toolbar(session)
            if session.find.isShowing {
                BrowserFindBar(
                    find: session.find,
                    focus: $isFindFocused,
                    type: session.typeInFind,
                    step: session.perform,
                    done: { session.perform(.hide) }
                )
            }
            if !session.downloads.isEmpty {
                BrowserDownloadsBar(
                    downloads: session.downloads, clear: session.clearDownloads
                )
            }
            ZStack {
                BrowserViewportView(
                    session: session, paneMenu: pageMenu, host: host,
                    isSelectingRegion: isSelectingRegion, regionCapture: regionCapture,
                    onViewportFrame: { viewportFrame = $0 }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let failure = session.failure {
                    EmptyStateView(
                        glyph: "exclamationmark.triangle",
                        title: failure.title,
                        message: failure.message,
                        actionTitle: "Try again",
                        action: { session.reload() }
                    )
                }
                if session.failure == nil, session.currentURL == nil {
                    EmptyStateView(
                        glyph: "globe",
                        title: "No page yet",
                        message: "Type an address above, or ask the agent to open one here."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "browser-feedback-pane")
            .overlay(alignment: .topLeading) {
                if let regionCapture {
                    BrowserRegionCaptureView(
                        capture: regionCapture, model: model, viewportFrame: viewportFrame,
                        add: addRegion
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if isSelectingRegion {
                    regionControls
                }
            }
            if ReviewComposer.isDrawn(destination: regionCapture?.sessionID ?? model.reviewDestination?.id, panes: siblings) {
                ReviewPaneComposer(model: model, room: room, destinationID: regionCapture?.sessionID)
            }
        }
        .onGeometryChange(for: CGFloat.self) { PaneMeasure.room($0.size.height) } action: { room.height = $0 }
        .task(id: isSelectingRegion) {
            guard isSelectingRegion, regionCapture == nil else { return }
            await prepareRegion()
        }
        .task(id: tab.id) {
            address = session.displayAddress
            if let held = model.browserReviews[tab.id] {
                regionCapture = held
                isSelectingRegion = true
            }
            if address.isEmpty { isAddressFocused = true }
            tabs.setPage(session.page, for: tab)
        }
        .onChange(of: session.page) {
            if !isAddressFocused { address = session.displayAddress }
            tabs.setPage(session.page, for: tab)
        }
    }

    private func toolbar(_ session: BrowserSession) -> some View {
        BrowserToolbarView(
            toolbar: BrowserToolbar(
                page: session.page,
                canGoBack: session.canGoBack,
                canGoForward: session.canGoForward,
                isLoading: session.isLoading,
                loadProgress: session.loadProgress,
                isCapturing: isCapturing || isSelectingRegion
            ),
            address: $address,
            addressFocus: $isAddressFocused,
            isRingVisible: isRingVisible,
            backHistory: session.backHistory,
            forwardHistory: session.forwardHistory,
            goBack: session.goBack,
            goForward: session.goForward,
            goToHistory: { session.go(back: $0) },
            reloadOrStop: {
                if session.isLoading { session.webView.stopLoading() } else { session.reload() }
            },
            capture: capture,
            captureRegion: isSelectingRegion ? cancelRegion : beginRegion,
            isReviewing: isSelectingRegion,
            isSavingReview: regionCapture?.isAdding == true,
            viewport: Binding(get: { session.viewport }, set: { session.viewport = $0 }),
            submit: {
                session.load(address)
                isAddressFocused = false
            }
        )
    }

    private var host: BrowserPaneHost {
        BrowserPaneHost(
            openTab: { [weak model] url in
                guard let model else { return }
                BrowserTab.openWindow(url, in: model)
            },
            report: { [weak app] notice in
                app?.alert = AppAlert(title: notice.title, message: notice.message)
            }
        )
    }

    @ViewBuilder private var regionControls: some View {
        if regionCapture?.isEditing != true && regionCapture?.focusedComment == nil {
            HStack(spacing: Metrics.spacingWide) {
                if let regionCapture {
                    Menu {
                        Button("Select All") {
                            regionCapture.selection = CGRect(x: 0, y: 0, width: 1, height: 1)
                            regionCapture.isEditing = true
                        }
                        Button("Clear Selection") { regionCapture.selection = nil }
                            .disabled(regionCapture.selection == nil)
                    } label: {
                        Image(systemName: "rectangle.dashed")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel("Selection")
                    Text(regionCapture.selection == nil ? "Drag to select an area" : "Area selected")
                        .font(Typo.caption)
                    if regionCapture.selection != nil {
                        Button("Comment") { regionCapture.isEditing = true }
                            .controlSize(.small)
                    }
                } else {
                    ProgressView().controlSize(.mini)
                    Text("Capturing page…").font(Typo.caption)
                }
                Button(regionCapture == nil ? "Cancel" : "Done", action: cancelRegion)
                    .buttonStyle(.borderless)
                    .font(Typo.caption)
                    .keyboardShortcut(.cancelAction)
            }
            .disabled(regionCapture?.isAdding == true)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: Metrics.corner))
            .overlay { RoundedRectangle(cornerRadius: Metrics.corner).strokeBorder(Palette.border, lineWidth: Metrics.outline) }
            .elevation(.resting)
            .padding(12)
        }
    }

    private func addRegion() {
        guard let regionCapture else { return }
        regionCapture.add(to: model) {
            model.browserReviews[tab.id] = regionCapture
        }
    }

    private func beginRegion() {
        guard !isCapturing, !isSelectingRegion else { return }
        isSelectingRegion = true
    }

    private func cancelRegion() {
        isSelectingRegion = false
        regionCapture = nil
        model.browserReviews[tab.id] = nil
    }

    private func prepareRegion() async {
        guard let destination = model.reviewDestination else {
            cancelRegion()
            app.alert = AppAlert(
                title: "No conversation yet",
                message: "Open a conversation in this workspace before adding feedback."
            )
            return
        }
        let session = self.session
        let address = session.displayAddress
        let pageRect = BrowserRegionCapture.pageRect(in: session)
        do {
            let data = try await session.snapshot()
            try Task.checkCancellation()
            guard address == session.displayAddress else {
                cancelRegion()
                app.alert = AppAlert(
                    title: "The page changed during capture",
                    message: "Wait for the page to finish loading, then select the area again."
                )
                return
            }
            regionCapture = try BrowserRegionCapture(
                data: data, address: address, session: destination,
                pageRect: pageRect, viewportSize: viewportFrame.size
            )
            model.browserReviews[tab.id] = regionCapture
        } catch {
            guard !Task.isCancelled else { return }
            cancelRegion()
            app.alert = AppAlert(title: "That page could not be captured", message: error.readableMessage)
        }
    }

    private func capture() {
        guard !isCapturing, !isSelectingRegion else { return }
        isCapturing = true
        Task {
            defer { isCapturing = false }
            let session = self.session
            let data: Data
            do {
                data = try await session.snapshot()
            } catch {
                app.alert = AppAlert(
                    title: "That page could not be captured",
                    message: error.readableMessage
                )
                return
            }

            let taken = Set(
                PromptAttachmentStore.shared
                    .attachments(for: model.activeSession?.id.rawValue ?? "")
                    .map(\.filename)
            )
            let name = BrowserSnapshot.filename(for: session.displayAddress, avoiding: taken)
            let outcome = await ComposerHandoff.attach(
                [.image(data, format: .png, named: name)], to: model,
                revealConversation: BrowserSnapshot.revealsConversation
            )
            guard let failure = outcome.failure else {
                app.notice = BrowserSnapshot.added(toConversation: model.activeSession?.title ?? "")
                return
            }
            app.alert = AppAlert(title: "That screenshot was not attached", message: failure)
        }
    }

    private func pageMenu() -> NSMenu {
        let menu = paneMenu?() ?? NSMenu()

        var items: [NSMenuItem] = [item(
            session.viewport.isEnabled ? "Restore Full Browser Size" : "Responsive Preview"
        ) { session.viewport.isEnabled.toggle() }]
        if let url = BrowserAddress.external(from: session.displayAddress) {
            items.append(item(BrowserToolbar().openInDefaultBrowser.name) { NSWorkspace.shared.open(url) })
        }
        if !isCapturing, !isSelectingRegion {
            items.append(item(BrowserToolbar().screenshot.name, perform: capture))
            if BrowserToolbar(page: session.page).regionCapture.isEnabled {
                items.append(item(BrowserToolbar().regionCapture.name, perform: beginRegion))
            }
        }
        guard !items.isEmpty else { return menu }

        if !menu.items.isEmpty { menu.insertItem(.separator(), at: 0) }
        for (offset, item) in items.enumerated() { menu.insertItem(item, at: offset) }
        return menu
    }

    private func item(
        _ title: String, perform: @escaping @MainActor () -> Void
    ) -> NSMenuItem {
        let target = PageMenuTarget(perform: perform)
        let item = NSMenuItem(
            title: title, action: #selector(PageMenuTarget.fire), keyEquivalent: ""
        )
        item.target = target
        item.representedObject = target
        return item
    }
}

@MainActor
final class PageMenuTarget: NSObject {
    private let perform: @MainActor () -> Void

    init(perform: @escaping @MainActor () -> Void) {
        self.perform = perform
    }

    @objc func fire() {
        perform()
    }
}
