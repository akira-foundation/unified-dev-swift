import Foundation

public enum ProfileSheetRequest: Identifiable, Hashable, Sendable {
    case new
    case edit(Profile)

    public var id: String {
        switch self {
        case .new: "new"
        case .edit(let profile): profile.id.rawValue
        }
    }

    public static func presenting(_ asked: ProfileSheetRequest, over open: ProfileSheetRequest?) -> ProfileSheetRequest {
        open ?? asked
    }
}
