import Foundation

public enum BrowserPaneStorage: Equatable, Sendable {
    case standard
    case dedicated(UUID)
}

public enum BrowserPaneAccess: String, Codable, Sendable, CaseIterable {
    case owner
    case agents

    public static let agentsStorageID = UUID(uuid: (
        0xE7, 0x4A, 0x1C, 0x52, 0x9B, 0x3D, 0x4F, 0x86,
        0xA2, 0x11, 0x6D, 0x0C, 0x5E, 0x8F, 0x47, 0xB3
    ))

    public static func restored(_ rawValue: String?) -> BrowserPaneAccess {
        rawValue.flatMap(BrowserPaneAccess.init(rawValue:)) ?? .owner
    }

    public var storage: BrowserPaneStorage {
        switch self {
        case .owner: .standard
        case .agents: .dedicated(Self.agentsStorageID)
        }
    }

    public var isOpenToAgents: Bool { self == .agents }

    public var toggled: BrowserPaneAccess { isOpenToAgents ? .owner : .agents }

    public func arrivalPage(from address: String) -> BrowserTabTitle.BrowserPage {
        BrowserTabTitle.BrowserPage(address: isOpenToAgents ? address : "")
    }

    public var emptyPageMessage: String {
        isOpenToAgents
            ? "Type an address above, or ask the agent to open one here."
            : "Type an address above."
    }

    public static let withheldName = "Owner's browser"

    public func nameForAgents(_ name: String) -> String {
        isOpenToAgents ? name : Self.withheldName
    }

    public static func refusal(number: Int, tool: String) -> String {
        "Browser \(number) belongs to the person you are working for, so \(tool) cannot use it and "
            + "Unified Dev does not report what it shows. Open a browser of your own with pane_open, "
            + "or ask them to share this one with the eye button in its toolbar."
    }

    public static func paneRefusal(verb: String) -> String {
        "That browser belongs to the person you are working for, so it was not \(verb)."
    }
}

extension BrowserToolbar {
    public static func agentAccess(_ access: BrowserPaneAccess, isDownloading: Bool = false) -> Control {
        guard !isDownloading else {
            return Control(
                symbol: access.isOpenToAgents ? "eye" : "eye.slash",
                name: access.isOpenToAgents ? "Stop Sharing This Browser with Agents" : "Share This Browser with Agents",
                help: "A download is running in this browser. Wait for it to finish first.",
                isEnabled: false,
                isActive: access.isOpenToAgents
            )
        }
        guard access.isOpenToAgents else {
            return Control(
                symbol: "eye.slash",
                name: "Share This Browser with Agents",
                help: "Agents cannot use this browser. Share it and the page reloads in the agents' "
                    + "browser, where you sign in separately.",
                isEnabled: true
            )
        }
        return Control(
            symbol: "eye",
            name: "Stop Sharing This Browser with Agents",
            help: "Agents can use this browser and anything signed in to the agents' browser, from "
                + "every workspace. Stop sharing and this pane starts blank.",
            isEnabled: true,
            isActive: true
        )
    }
}
