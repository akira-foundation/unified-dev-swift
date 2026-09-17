import AppIntents
import Foundation

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case unknownProject
    case unknownWorkspace
    case appNeverAppeared

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unknownProject:
            "That project is no longer one of Unified Dev's. Add its folder in Unified Dev and try again."
        case .unknownWorkspace:
            "That workspace no longer exists in Unified Dev."
        case .appNeverAppeared:
            "Unified Dev did not finish opening, so there was nowhere to send the request."
        }
    }
}
