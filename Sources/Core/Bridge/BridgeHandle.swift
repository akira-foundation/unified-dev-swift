import Foundation

public struct BridgeHandle: Sendable, Hashable {
    public let attachment: BridgeAttachment
    public let mcpConfigPath: String?

    public init(attachment: BridgeAttachment, mcpConfigPath: String?) {
        self.attachment = attachment
        self.mcpConfigPath = mcpConfigPath
    }
}
