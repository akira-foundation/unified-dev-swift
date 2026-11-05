import Core
import SwiftUI

struct ProfileMoveTargets: View {
    var targets: [Profile]
    var onMove: (ProfileID) -> Void

    var body: some View {
        ForEach(targets) { profile in
            Button {
                onMove(profile.id)
            } label: {
                ProfileMenuLabel(profile: profile)
            }
        }
    }
}
