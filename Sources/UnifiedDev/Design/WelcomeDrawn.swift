import Foundation
import SwiftUI

#if DEBUG
@MainActor
enum WelcomeDrawn {
    nonisolated static let space = "welcome-stage"

    private(set) static var stages: [String: [String: CGRect]] = [:]

    static func note(_ part: String, of stage: String, frame: CGRect) {
        stages[stage, default: [:]][part] = frame
    }

    static func forget() {
        stages = [:]
    }
}
#else
enum WelcomeDrawn {
    nonisolated static let space = "welcome-stage"
}
#endif

extension View {
    func welcomeDrawn(_ part: String, of stage: String) -> some View {
        #if DEBUG
        return onGeometryChange(for: CGRect.self) { $0.frame(in: .named(WelcomeDrawn.space)) } action: { frame in
            MainActor.assumeIsolated { WelcomeDrawn.note(part, of: stage, frame: frame) }
        }
        #else
        return self
        #endif
    }
}
