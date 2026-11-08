import CoreGraphics

public struct ProfileToolbarLabel: Equatable, Sendable {
    public static let occupiedBesideMenu: CGFloat = 152

    public static let smallestMenuWithName: CGFloat = 74

    public let menuWidth: CGFloat?

    public let help: String

    public let accessibilityLabel: String

    public static func resolve(profileName: String, drawsSidebar: Bool, sidebarWidth: CGFloat) -> ProfileToolbarLabel {
        let room = (sidebarWidth - occupiedBesideMenu).rounded(.down)
        return ProfileToolbarLabel(
            menuWidth: drawsSidebar && room >= smallestMenuWithName ? room : nil,
            help: "Switch profile, \(profileName)",
            accessibilityLabel: "Profile, \(profileName)"
        )
    }
}
