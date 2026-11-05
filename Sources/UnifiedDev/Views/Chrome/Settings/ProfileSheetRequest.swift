import Core

enum ProfileSheetRequest: Identifiable {
    case new
    case edit(Profile)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let profile): profile.id.rawValue
        }
    }
}
