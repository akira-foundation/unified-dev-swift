import AppKit
import SwiftUI
import Core

@MainActor
enum WindowRoles {
    private static let marks = NSMapTable<NSWindow, NSString>.weakToStrongObjects()

    static func mark(_ window: NSWindow, as role: WindowDismissal.Role) {
        marks.setObject(role.rawValue as NSString, forKey: window)
    }

    static func anchorCandidate(_ window: NSWindow) -> WelcomeAnchorCandidate {
        WelcomeAnchorCandidate(
            role: role(of: window),
            isVisible: window.isVisible,
            isSheet: window.isSheet,
            isPanel: window is NSPanel,
            hasParent: window.parent != nil
        )
    }

    static func target(_ window: NSWindow) -> WindowDismissal.Target {
        WindowDismissal.Target(
            role: role(of: window),
            isClosable: window.styleMask.contains(.closable),
            isSheet: window.isSheet,
            hasAttachedSheet: window.attachedSheet != nil
        )
    }

    private static func role(of window: NSWindow) -> WindowDismissal.Role {
        guard let raw = marks.object(forKey: window) as String?,
              let role = WindowDismissal.Role(rawValue: raw)
        else { return .workspace }
        return role
    }
}

private struct WindowRoleMarker: ViewModifier {
    let role: WindowDismissal.Role

    @State private var window: NSWindow?

    func body(content: Content) -> some View {
        content
            .background(WindowAccessor(window: $window))
            .onChange(of: window, initial: true) { _, _ in
                guard let window else { return }
                WindowRoles.mark(window, as: role)
            }
    }
}

extension View {
    func windowRole(_ role: WindowDismissal.Role) -> some View {
        modifier(WindowRoleMarker(role: role))
    }
}
