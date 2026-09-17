import Foundation

enum AppNotReady: Error, CustomStringConvertible {
    case stillStartingUp

    var description: String {
        switch self {
        case .stillStartingUp:
            "Unified Dev is still starting up, so there was nothing to do the work with yet. Try again."
        }
    }
}
