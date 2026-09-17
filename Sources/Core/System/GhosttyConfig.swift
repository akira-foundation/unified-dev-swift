import Foundation

public struct GhosttyColor: Sendable, Hashable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init?(hex: String) {
        guard let parsed = HexColor(hex: hex) else { return nil }
        self.init(red: parsed.red, green: parsed.green, blue: parsed.blue)
    }
}

public enum GhosttyAppearance: String, Sendable, Hashable {
    case light
    case dark
}

public struct GhosttyTheme: Sendable, Hashable {
    public var background: GhosttyColor?
    public var foreground: GhosttyColor?
    public var cursorColor: GhosttyColor?
    public var cursorTextColor: GhosttyColor?
    public var selectionBackground: GhosttyColor?
    public var selectionForeground: GhosttyColor?
    public var palette: [Int: GhosttyColor] = [:]
    public var fontFamily: String?
    public var fontSize: Double?

    public init() {}

    public var isEmpty: Bool {
        background == nil
            && foreground == nil
            && cursorColor == nil
            && cursorTextColor == nil
            && selectionBackground == nil
            && selectionForeground == nil
            && palette.isEmpty
            && fontFamily == nil
            && fontSize == nil
    }

    public func ansiColors() -> [GhosttyColor] {
        (0..<16).map { palette[$0] ?? Self.defaultPalette[$0] }
    }

    public static let defaultPalette: [GhosttyColor] = [
        GhosttyColor(red: 0x1D, green: 0x1F, blue: 0x21),
        GhosttyColor(red: 0xCC, green: 0x66, blue: 0x66),
        GhosttyColor(red: 0xB5, green: 0xBD, blue: 0x68),
        GhosttyColor(red: 0xF0, green: 0xC6, blue: 0x74),
        GhosttyColor(red: 0x81, green: 0xA2, blue: 0xBE),
        GhosttyColor(red: 0xB2, green: 0x94, blue: 0xBB),
        GhosttyColor(red: 0x8A, green: 0xBE, blue: 0xB7),
        GhosttyColor(red: 0xC5, green: 0xC8, blue: 0xC6),
        GhosttyColor(red: 0x66, green: 0x66, blue: 0x66),
        GhosttyColor(red: 0xD5, green: 0x4E, blue: 0x53),
        GhosttyColor(red: 0xB9, green: 0xCA, blue: 0x4A),
        GhosttyColor(red: 0xE7, green: 0xC5, blue: 0x47),
        GhosttyColor(red: 0x7A, green: 0xA6, blue: 0xDA),
        GhosttyColor(red: 0xC3, green: 0x97, blue: 0xD8),
        GhosttyColor(red: 0x70, green: 0xC0, blue: 0xB1),
        GhosttyColor(red: 0xEA, green: 0xEA, blue: 0xEA),
    ]
}

public enum GhosttyConfigParser {
    public struct Entry: Sendable, Hashable {
        public var key: String
        public var value: String

        public init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    public static func parse(_ text: String) -> [Entry] {
        text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

            guard let separator = line.firstIndex(of: "=") else {
                return Entry(key: line, value: "")
            }

            return Entry(
                key: String(line[line.startIndex..<separator]).trimmingCharacters(in: .whitespaces),
                value: String(line[line.index(after: separator)...])
                    .trimmingCharacters(in: .whitespaces)
            )
        }
    }
}

public enum GhosttyConfigResolver {
    public static func resolve(
        sources: [String],
        appearance: GhosttyAppearance,
        themeText: (String) -> String? = { _ in nil }
    ) -> GhosttyTheme {
        var explicit = GhosttyTheme()
        var themeSetting: String?

        for source in sources {
            for entry in GhosttyConfigParser.parse(source) {
                if entry.key == "theme" {
                    themeSetting = entry.value.isEmpty ? nil : entry.value
                    continue
                }
                apply(entry, to: &explicit)
            }
        }

        guard let name = themeSetting.flatMap({ themeName($0, appearance: appearance) }),
              let text = themeText(name) else {
            return explicit
        }

        var resolved = GhosttyTheme()
        for entry in GhosttyConfigParser.parse(text) where entry.key != "theme" {
            apply(entry, to: &resolved)
        }
        merge(explicit, into: &resolved)
        return resolved
    }

    public static func themeName(_ setting: String, appearance: GhosttyAppearance) -> String? {
        let parts = setting.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let pairs = parts.compactMap { part -> (GhosttyAppearance, String)? in
            guard let separator = part.firstIndex(of: ":") else { return nil }
            let side = String(part[part.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
            let name = String(part[part.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            guard let appearance = GhosttyAppearance(rawValue: side.lowercased()), !name.isEmpty else {
                return nil
            }
            return (appearance, name)
        }

        guard pairs.count == parts.count, pairs.count > 1 else {
            return setting.isEmpty ? nil : setting
        }
        return pairs.first { $0.0 == appearance }?.1
    }

    private static func apply(_ entry: GhosttyConfigParser.Entry, to theme: inout GhosttyTheme) {
        let reset = entry.value.isEmpty

        switch entry.key {
        case "background":
            theme.background = reset ? nil : GhosttyColor(hex: entry.value) ?? theme.background
        case "foreground":
            theme.foreground = reset ? nil : GhosttyColor(hex: entry.value) ?? theme.foreground
        case "cursor-color":
            theme.cursorColor = reset ? nil : GhosttyColor(hex: entry.value) ?? theme.cursorColor
        case "cursor-text":
            theme.cursorTextColor = reset
                ? nil
                : GhosttyColor(hex: entry.value) ?? theme.cursorTextColor
        case "selection-background":
            theme.selectionBackground = reset
                ? nil
                : GhosttyColor(hex: entry.value) ?? theme.selectionBackground
        case "selection-foreground":
            theme.selectionForeground = reset
                ? nil
                : GhosttyColor(hex: entry.value) ?? theme.selectionForeground
        case "font-family":
            if reset {
                theme.fontFamily = nil
            } else if theme.fontFamily == nil {
                theme.fontFamily = entry.value
            }
        case "font-size":
            theme.fontSize = reset ? nil : Double(entry.value) ?? theme.fontSize
        case "palette":
            guard !reset else {
                theme.palette.removeAll()
                return
            }
            guard let separator = entry.value.firstIndex(of: "=") else { return }
            let index = Int(
                entry.value[entry.value.startIndex..<separator].trimmingCharacters(in: .whitespaces)
            )
            let color = GhosttyColor(
                hex: String(entry.value[entry.value.index(after: separator)...])
            )
            guard let index, (0...255).contains(index), let color else { return }
            theme.palette[index] = color
        default:
            break
        }
    }

    private static func merge(_ overlay: GhosttyTheme, into base: inout GhosttyTheme) {
        base.background = overlay.background ?? base.background
        base.foreground = overlay.foreground ?? base.foreground
        base.cursorColor = overlay.cursorColor ?? base.cursorColor
        base.cursorTextColor = overlay.cursorTextColor ?? base.cursorTextColor
        base.selectionBackground = overlay.selectionBackground ?? base.selectionBackground
        base.selectionForeground = overlay.selectionForeground ?? base.selectionForeground
        base.fontFamily = overlay.fontFamily ?? base.fontFamily
        base.fontSize = overlay.fontSize ?? base.fontSize
        base.palette.merge(overlay.palette) { _, explicit in explicit }
    }
}

public enum GhosttyConfigLoader {
    public static func configPaths(
        home: String = NSHomeDirectory(),
        xdgConfigHome: String? = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
    ) -> [String] {
        let xdg = xdgConfigHome.flatMap { $0.isEmpty ? nil : $0 } ?? "\(home)/.config"
        return [
            "\(xdg)/ghostty/config",
            "\(xdg)/ghostty/config.ghostty",
            "\(home)/Library/Application Support/com.mitchellh.ghostty/config",
            "\(home)/Library/Application Support/com.mitchellh.ghostty/config.ghostty",
        ]
    }

    public static func themeDirectories(
        home: String = NSHomeDirectory(),
        xdgConfigHome: String? = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
        resources: [String] = resourceThemeDirectories
    ) -> [String] {
        let xdg = xdgConfigHome.flatMap { $0.isEmpty ? nil : $0 } ?? "\(home)/.config"
        return ["\(xdg)/ghostty/themes"] + resources
    }

    public static let resourceThemeDirectories = [
        "/Applications/Ghostty.app/Contents/Resources/ghostty/themes",
        "\(NSHomeDirectory())/Applications/Ghostty.app/Contents/Resources/ghostty/themes",
    ]

    public static func load(
        appearance: GhosttyAppearance,
        paths: [String] = configPaths(),
        themeDirectories: [String] = themeDirectories()
    ) -> GhosttyTheme? {
        let sources = paths.compactMap { try? String(contentsOfFile: $0, encoding: .utf8) }
        guard !sources.isEmpty else { return nil }

        let theme = GhosttyConfigResolver.resolve(sources: sources, appearance: appearance) { name in
            themeText(named: name, in: themeDirectories)
        }
        return theme.isEmpty ? nil : theme
    }

    public static func themeText(named name: String, in directories: [String]) -> String? {
        if name.hasPrefix("/") {
            return try? String(contentsOfFile: name, encoding: .utf8)
        }
        guard !name.contains("/") else { return nil }

        for directory in directories {
            let path = (directory as NSString).appendingPathComponent(name)
            if let text = try? String(contentsOfFile: path, encoding: .utf8) { return text }
        }
        return nil
    }
}
