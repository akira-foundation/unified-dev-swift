import Core
import SwiftUI

extension TranscriptListView {
    func sendingSlotEntry(_ sending: Delivery?) -> TranscriptTableEntry {
        TranscriptTableEntry(
            id: .sending,
            contentKey: TranscriptContentKey {
                $0.combine("sending")
                $0.combine(transcript.session.id)
                $0.combine(sending?.id)
            },
            content: {
                guard let sending else { return AnyView(EmptyView()) }
                switch SendingSlot.drawing(of: sending) {
                case .workspaceMessage(let crew):
                    return AnyView(
                        WorkspaceMessageRowView(message: crew)
                            .messageArrival(transcript.messageArrivals.delivery(sending.id))
                            .padding(.horizontal, TranscriptLayout.inset)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
                case .crewMessage(let crew):
                    return AnyView(
                        CrewMessageRowView(message: crew)
                            .padding(.horizontal, TranscriptLayout.inset)
                    )
                case .ownerTurn:
                    return ownerTurn(sending)
                case nil:
                    return AnyView(EmptyView())
                }
            }
        )
    }

    private func ownerTurn(_ sending: Delivery) -> AnyView {
        let review = ReviewTurn.split(sending.body)
        let turn = AttachmentTrailer.split(sending.body)
        return AnyView(
            Group {
                if let review {
                    UserTurnRowView(
                        text: review.message,
                        reviewChips: review.chips,
                        home: transcript.home
                    )
                } else {
                    UserTurnRowView(
                        text: turn.body,
                        attachments: turn.paths,
                        home: transcript.home
                    )
                }
            }
            .messageArrival(transcript.messageArrivals.delivery(sending.id))
            .padding(.horizontal, TranscriptLayout.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
        )
    }
}
