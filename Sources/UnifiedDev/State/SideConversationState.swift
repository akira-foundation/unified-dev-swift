import Core
import Foundation
import Observation

@MainActor
@Observable
final class SideConversationState {
    var transcript: TranscriptModel?
    var snapshot: SideConversation.Snapshot?
    var isVisible = false
    var isOpening = false
    var error: String?
    var pendingQuestion = ""
    @ObservationIgnored var task: Task<Void, Never>?
}
