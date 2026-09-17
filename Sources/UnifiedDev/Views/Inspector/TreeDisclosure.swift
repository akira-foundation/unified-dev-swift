import SwiftUI
import Core

extension TreeDisclosureMotion {
    var animation: Animation? {
        seconds.map { .easeOut(duration: $0) }
    }
}
