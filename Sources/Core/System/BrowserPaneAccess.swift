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
}
