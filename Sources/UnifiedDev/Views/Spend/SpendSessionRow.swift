import SwiftUI
import Core

struct SpendSessionRow: View {
    let session: SpendSessionLine

    var body: some View {
        LabeledContent {
            Text(SpendLines.cost(session.spend)).monospacedDigit()
        } label: {
            Label(session.agentSessionID, systemImage: "circle.fill")
                .labelStyle(SpendDotLabelStyle(
                    ink: Color(hexString: ProviderAccent.hex(for: session.provider))
                ))
            Text(SpendLines.sessionCaption(session))
        }
    }
}
