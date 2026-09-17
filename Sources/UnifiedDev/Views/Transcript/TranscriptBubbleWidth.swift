import SwiftUI
import Observation

@MainActor
@Observable
final class TranscriptBubbleWidth {
    var cap: CGFloat = 240
}

extension EnvironmentValues {
    @Entry var transcriptBubbleWidth: TranscriptBubbleWidth?
}
