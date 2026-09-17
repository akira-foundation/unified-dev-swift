import Foundation

enum RepoIconFile {
    struct Measurement: Sendable, Hashable {
        var format: RepoIconFormat
        var pixels: Int
        var aspect: Double?

        init(format: RepoIconFormat, pixels: Int, aspect: Double? = 1) {
            self.format = format
            self.pixels = pixels
            self.aspect = aspect
        }
    }

    static func measure(_ path: String) -> Measurement? {
        let lower = path.lowercased()
        if lower.hasSuffix(".icon") { return measureIconBundle(path) }

        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        if lower.hasSuffix(".png") { return measurePNG(handle) }
        if lower.hasSuffix(".ico") { return measureICO(handle) }
        if lower.hasSuffix(".icns") { return measureICNS(handle) }
        if lower.hasSuffix(".svg") { return measureSVG(handle) }
        if lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") { return measureJPEG(handle) }
        return nil
    }

    private static func measurePNG(_ handle: FileHandle) -> Measurement? {
        guard let header = read(handle, at: 0, count: 24), header.count == 24 else { return nil }
        let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard Array(header[0..<8]) == magic else { return nil }
        guard Array(header[12..<16]) == Array("IHDR".utf8) else { return nil }

        let width = Int(be32(header, at: 16))
        let height = Int(be32(header, at: 20))
        guard width > 0, height > 0 else { return nil }
        return Measurement(
            format: .png,
            pixels: max(width, height),
            aspect: Double(max(width, height)) / Double(min(width, height))
        )
    }

    private static func measureICO(_ handle: FileHandle) -> Measurement? {
        guard let header = read(handle, at: 0, count: 6), header.count == 6 else { return nil }
        guard le16(header, at: 0) == 0, le16(header, at: 2) == 1 else { return nil }
        let count = Int(le16(header, at: 4))
        guard count > 0, count < 512 else { return nil }

        guard let directory = read(handle, at: 6, count: count * 16),
              directory.count == count * 16
        else { return nil }

        var largest = 0
        for index in 0..<count {
            let width = Int(directory[index * 16])
            let height = Int(directory[index * 16 + 1])
            largest = max(largest, max(width == 0 ? 256 : width, height == 0 ? 256 : height))
        }
        guard largest > 0 else { return nil }
        return Measurement(format: .ico, pixels: largest)
    }

    private static func measureJPEG(_ handle: FileHandle) -> Measurement? {
        guard let start = read(handle, at: 0, count: 2), start == [0xFF, 0xD8] else { return nil }
        let end = (try? handle.seekToEnd()) ?? 0

        var offset: UInt64 = 2
        while offset + 4 <= end {
            guard let head = read(handle, at: offset, count: 4), head.count == 4 else { return nil }
            guard head[0] == 0xFF else { return nil }
            let marker = head[1]

            if marker == 0xFF { offset += 1; continue }
            if marker == 0x01 || (0xD0...0xD8).contains(marker) { offset += 2; continue }
            if marker == 0xDA || marker == 0xD9 { return nil }

            if frameMarkers.contains(marker) {
                guard let frame = read(handle, at: offset + 4, count: 5), frame.count == 5
                else { return nil }
                let height = Int(frame[1]) << 8 | Int(frame[2])
                let width = Int(frame[3]) << 8 | Int(frame[4])
                guard width > 0, height > 0 else { return nil }
                return Measurement(
                    format: .jpeg,
                    pixels: max(width, height),
                    aspect: Double(max(width, height)) / Double(min(width, height))
                )
            }

            let length = UInt64(Int(head[2]) << 8 | Int(head[3]))
            guard length >= 2 else { return nil }
            offset += 2 + length
        }
        return nil
    }

    private static let frameMarkers: Set<UInt8> = [
        0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
    ]

    private static func measureICNS(_ handle: FileHandle) -> Measurement? {
        guard let header = read(handle, at: 0, count: 8), header.count == 8 else { return nil }
        guard Array(header[0..<4]) == Array("icns".utf8) else { return nil }

        let declared = UInt64(be32(header, at: 4))
        let actual = (try? handle.seekToEnd()) ?? 0
        let end = min(declared, actual)
        guard end > 8 else { return nil }

        var offset: UInt64 = 8
        var largest = 0
        while offset + 8 <= end {
            guard let chunk = read(handle, at: offset, count: 8), chunk.count == 8 else { break }
            let type = String(decoding: chunk[0..<4], as: UTF8.self)
            let length = UInt64(be32(chunk, at: 4))
            guard length >= 8, offset + length <= end else { break }
            if let size = icnsSizes[type] { largest = max(largest, size) }
            offset += length
        }
        guard largest > 0 else { return nil }
        return Measurement(format: .icns, pixels: largest)
    }

    private static let icnsSizes: [String: Int] = [
        "ICON": 32, "ICN#": 32,
        "icm#": 16, "icm4": 16, "icm8": 16,
        "ics#": 16, "ics4": 16, "ics8": 16, "is32": 16, "icp4": 16, "ic04": 16,
        "icl4": 32, "icl8": 32, "il32": 32, "icp5": 32, "ic05": 32, "ic11": 32,
        "sb24": 24, "icsb": 36,
        "ich#": 48, "ich4": 48, "ich8": 48, "ih32": 48, "SB24": 48,
        "icp6": 64, "ic12": 64, "icsB": 64,
        "it32": 128, "ic07": 128,
        "ic08": 256, "ic13": 256,
        "ic09": 512, "ic14": 512,
        "ic10": 1024,
    ]

    private static func measureSVG(_ handle: FileHandle) -> Measurement? {
        guard let head = read(handle, at: 0, count: 16 * 1024), !head.isEmpty else { return nil }
        let text = String(decoding: head, as: UTF8.self).lowercased()
        guard let start = text.range(of: "<svg"), !text.contains("<html") else { return nil }

        let tail = text[start.upperBound...]
        let tag = String(tail.prefix(while: { $0 != ">" }))
        return Measurement(format: .svg, pixels: 0, aspect: aspect(ofSVGTag: tag))
    }

    private static func aspect(ofSVGTag tag: String) -> Double? {
        if let box = attribute("viewbox", in: tag) {
            let numbers = box
                .components(separatedBy: CharacterSet(charactersIn: ", \t\n"))
                .compactMap(Double.init)
            if numbers.count == 4, numbers[2] > 0, numbers[3] > 0 {
                return max(numbers[2], numbers[3]) / min(numbers[2], numbers[3])
            }
        }
        guard let width = length(attribute("width", in: tag)),
              let height = length(attribute("height", in: tag))
        else { return nil }
        return max(width, height) / min(width, height)
    }

    private static func length(_ value: String?) -> Double? {
        guard var value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty,
              !value.hasSuffix("%") else { return nil }
        for unit in ["px", "pt"] where value.hasSuffix(unit) {
            value = String(value.dropLast(unit.count))
        }
        guard let number = Double(value), number > 0 else { return nil }
        return number
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        for quote in ["\"", "'"] {
            guard let range = tag.range(of: "\(name)=\(quote)") else { continue }
            let rest = tag[range.upperBound...]
            guard let end = rest.firstIndex(of: Character(quote)) else { continue }
            return String(rest[..<end])
        }
        return nil
    }

    private static func measureIconBundle(_ path: String) -> Measurement? {
        guard !layers(ofIconBundle: path).isEmpty else { return nil }
        return Measurement(format: .layered, pixels: 0)
    }

    static func layers(ofIconBundle path: String) -> [RepoIconLayer] {
        let manifest = (path as NSString).appendingPathComponent("icon.json")
        guard let data = RepoIconDetector.boundedContents(ofFile: manifest, limit: 1024 * 1024),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = object["groups"] as? [[String: Any]]
        else { return [] }

        var described: [(name: String, fill: RepoIconLayerFill, opacity: Double)] = []
        for group in groups {
            guard let layers = group["layers"] as? [[String: Any]] else { continue }
            for layer in layers {
                guard let name = layer["image-name"] as? String, !name.isEmpty else { continue }
                if layer["hidden"] as? Bool == true { continue }
                described.append((
                    name,
                    fill(from: layer["fill"]),
                    (layer["opacity"] as? Double).map { max(0, min(1, $0)) } ?? 1
                ))
            }
        }

        return described.reversed().compactMap { layer in
            let assets = (path as NSString).appendingPathComponent("Assets/\(layer.name)")
            if FileManager.default.fileExists(atPath: assets) {
                return RepoIconLayer(path: assets, fill: layer.fill, opacity: layer.opacity)
            }
            let loose = (path as NSString).appendingPathComponent(layer.name)
            if FileManager.default.fileExists(atPath: loose) {
                return RepoIconLayer(path: loose, fill: layer.fill, opacity: layer.opacity)
            }
            return nil
        }
    }

    private static func fill(from value: Any?) -> RepoIconLayerFill {
        if let text = value as? String {
            return colour(text).map(RepoIconLayerFill.solid) ?? .artwork
        }
        guard let object = value as? [String: Any] else { return .artwork }

        if let stops = object["linear-gradient"] as? [String], stops.count >= 2,
           let from = colour(stops[0]), let to = colour(stops[1]) {
            let orientation = object["orientation"] as? [String: Any]
            return .linearGradient(
                from: from,
                to: to,
                start: point(orientation?["start"], fallbackY: 0),
                stop: point(orientation?["stop"], fallbackY: 1)
            )
        }

        if let single = object["automatic-gradient"] as? String, let only = colour(single) {
            return .solid(only)
        }
        return .artwork
    }

    private static func point(_ value: Any?, fallbackY: Double) -> RepoIconLayerPoint {
        guard let object = value as? [String: Any] else {
            return RepoIconLayerPoint(x: 0.5, y: fallbackY)
        }
        return RepoIconLayerPoint(
            x: object["x"] as? Double ?? 0.5,
            y: object["y"] as? Double ?? fallbackY
        )
    }

    static func colour(_ text: String) -> RepoIconColour? {
        if let hex = HexColor(hex: text) {
            return RepoIconColour(
                red: Double(hex.red) / 255,
                green: Double(hex.green) / 255,
                blue: Double(hex.blue) / 255,
                alpha: 1
            )
        }
        guard let separator = text.lastIndex(of: ":") else { return nil }
        let channels = text[text.index(after: separator)...]
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard channels.count >= 3 else { return nil }
        return RepoIconColour(
            red: channels[0],
            green: channels[1],
            blue: channels[2],
            alpha: channels.count > 3 ? channels[3] : 1
        )
    }

    private static func read(_ handle: FileHandle, at offset: UInt64, count: Int) -> [UInt8]? {
        do {
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: count) else { return nil }
            return [UInt8](data)
        } catch {
            return nil
        }
    }

    private static func be32(_ bytes: [UInt8], at index: Int) -> UInt32 {
        UInt32(bytes[index]) << 24 | UInt32(bytes[index + 1]) << 16
            | UInt32(bytes[index + 2]) << 8 | UInt32(bytes[index + 3])
    }

    private static func le16(_ bytes: [UInt8], at index: Int) -> UInt16 {
        UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
    }
}

public struct RepoIconLayer: Sendable, Hashable {
    public var path: String
    public var fill: RepoIconLayerFill
    public var opacity: Double

    public init(path: String, fill: RepoIconLayerFill = .artwork, opacity: Double = 1) {
        self.path = path
        self.fill = fill
        self.opacity = opacity
    }
}

public enum RepoIconLayerFill: Sendable, Hashable {
    case artwork
    case solid(RepoIconColour)
    case linearGradient(
        from: RepoIconColour,
        to: RepoIconColour,
        start: RepoIconLayerPoint,
        stop: RepoIconLayerPoint
    )
}

public struct RepoIconColour: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct RepoIconLayerPoint: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
