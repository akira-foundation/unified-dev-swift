import CoreGraphics

public struct ProfileToolbarLabel: Equatable, Sendable {
    public static let occupiedBesideMenu: CGFloat = 152

    public static let smallestMenuWithName: CGFloat = 74

    public let menuWidth: CGFloat?

    public let sitsOnGlass: Bool

    public let help: String

    public let accessibilityLabel: String

    public let measureKey: String

    public static func barIsHidden(isFullScreen: Bool, trafficLightsOpacity: CGFloat) -> Bool {
        isFullScreen && trafficLightsOpacity < 0.5
    }

    public static func resolve(profileName: String, drawsSidebar: Bool, barIsHidden: Bool = false, sidebarWidth: CGFloat) -> ProfileToolbarLabel {
        let room = (sidebarWidth - occupiedBesideMenu).rounded(.down)
        let showsName = drawsSidebar && !barIsHidden && room >= smallestMenuWithName
        return ProfileToolbarLabel(
            menuWidth: showsName ? room : nil,
            sitsOnGlass: !showsName,
            help: "Switch profile, \(profileName)",
            accessibilityLabel: "Profile, \(profileName)",
            measureKey: "\(profileName)|\(showsName ? room : 0)|\(barIsHidden)"
        )
    }
}
