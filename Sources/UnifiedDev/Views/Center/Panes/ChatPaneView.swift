import SwiftUI
import Core

struct ChatPaneView: View {
    var transcript: TranscriptModel
    @Bindable var model: WorkspaceModel
    var pane: String

    @State private var isTranscriptScrolledUp = false

    @State private var room = ComposerRoom()
    @State private var sideOrigin: SideConversation.Snapshot?

    @AppStorage(ChatTextSize.defaultsKey) private var textSize = ChatTextSize.defaultChoice
    @AppStorage(ChatFont.defaultsKey) private var chatFontID = ChatFont.standardID
    @AppStorage(ChatLineHeight.defaultsKey) private var lineHeight = ChatLineHeight.defaultChoice

    private var waiting: PaneWait? {
        transcript.isLoaded ? nil : .conversation(transcript.session.id)
    }

    var body: some View {
        TranscriptView(
            transcript: transcript,
            isRunningSetup: model.isRunningSetup,
            memory: TranscriptPaneMemory(model: model, pane: pane)
        ) { isTranscriptScrolledUp = $0 }
        .mask(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                Color.clear.frame(height: ComposerLayout.coverHeight)
            }
            .padding(.top, -SplitPaneFrame.underBarReach)
        }
        .environment(\.composerRoom, room)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            SlowLoadingView(subject: waiting, label: waiting?.label)
                .padding(.bottom, room.clearance)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            ComposerDock(
                showsJumpToNewest: isTranscriptScrolledUp,
                onJumpToNewest: transcript.jumpToLiveEnd
            ) {
                ComposerView(transcript: transcript, model: model, room: room)
            }
        }
        .overlay(alignment: .topLeading) {
            if let origin = sideOrigin, transcript.session.sideConversationParentID == nil {
                Button {
                    WorkspaceTabsStore.shared.reveal(.chat(origin.parentID), in: model)
                } label: {
                    Label("From \(origin.title)", systemImage: "arrow.turn.up.left")
                        .font(.caption)
                        .padding(8)
                }
                .buttonStyle(.glass)
                .disabled(!model.sessions.contains { $0.id == origin.parentID })
                .padding(8)
            }
        }
        .overlay {
            if let state = model.sideConversations[transcript.session.id], state.isVisible {
                GeometryReader { geometry in
                    let bottom = geometry.size.height - room.clearance >= 360 ? room.clearance + 8 : 8
                    SideConversationView(parent: transcript, state: state, model: model)
                        .frame(
                            width: max(0, min(560, geometry.size.width - 24)),
                            height: max(0, min(520, geometry.size.height - bottom - 12))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 12)
                        .padding(.bottom, bottom)
                }
            }
        }
        .task(id: transcript.session.id) {
            let origin = try? await model.store?.sideConversationSnapshot(sessionID: transcript.session.id)
            guard !Task.isCancelled else { return }
            sideOrigin = origin
        }
        .onGeometryChange(for: CGFloat.self) { PaneMeasure.room($0.size.height) } action: {
            room.height = $0
        }
        .environment(\.fontScale, textSize.scale)
        .environment(\.chatFont, ChatFont(rawValue: chatFontID))
        .environment(\.chatLineHeight, lineHeight)
    }
}
