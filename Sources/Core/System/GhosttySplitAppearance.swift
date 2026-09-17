import Foundation

public struct GhosttySplitAppearance: Sendable, Hashable {
    public var unfocusedOpacity: Double?
    public var unfocusedFill: GhosttyColor?
    public var dividerColor: GhosttyColor?

    public init(
        unfocusedOpacity: Double? = nil,
        unfocusedFill: GhosttyColor? = nil,
        dividerColor: GhosttyColor? = nil
    ) {
        self.unfocusedOpacity = unfocusedOpacity
        self.unfocusedFill = unfocusedFill
        self.dividerColor = dividerColor
    }

    public var isEmpty: Bool {
        unfocusedOpacity == nil && unfocusedFill == nil && dividerColor == nil
    }

    public static func resolve(sources: [String]) -> GhosttySplitAppearance {
        var appearance = GhosttySplitAppearance()

        for source in sources {
            for entry in GhosttyConfigParser.parse(source) {
                let reset = entry.value.isEmpty

                switch entry.key {
                case "unfocused-split-opacity":
                    guard !reset else {
                        appearance.unfocusedOpacity = nil
                        continue
                    }
                    guard let value = Double(entry.value), value > 0, value <= 1 else { continue }
                    appearance.unfocusedOpacity = value

                case "unfocused-split-fill":
                    appearance.unfocusedFill = reset ? nil : GhosttyColor(hex: entry.value)
                        ?? appearance.unfocusedFill

                case "split-divider-color":
                    appearance.dividerColor = reset ? nil : GhosttyColor(hex: entry.value)
                        ?? appearance.dividerColor

                default:
                    break
                }
            }
        }

        return appearance
    }

    public static func load(paths: [String] = GhosttyConfigLoader.configPaths()) -> GhosttySplitAppearance {
        resolve(sources: paths.compactMap { try? String(contentsOfFile: $0, encoding: .utf8) })
    }
}
