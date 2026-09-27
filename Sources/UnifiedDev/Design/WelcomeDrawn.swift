import Foundation
import SwiftUI

@MainActor
enum WelcomeDrawn {
    nonisolated static let space = "welcome-stage"

    private(set) static var stages: [String: [String: CGRect]] = [:]

    static func note(_ part: String, of stage: String, frame: CGRect) {
        stages[stage, default: [:]][part] = frame
    }
}

extension View {
    func welcomeDrawn(_ part: String, of stage: String) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(WelcomeDrawn.space)) } action: { frame in
            MainActor.assumeIsolated { WelcomeDrawn.note(part, of: stage, frame: frame) }
        }
    }
}
