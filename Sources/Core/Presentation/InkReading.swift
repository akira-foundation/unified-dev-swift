import CoreGraphics

public struct InkReading: Equatable, Sendable {
    public static let apart = 0.06

    public static let leastSide = 4

    public static let samplesAcross = 200

    public var ink = WindowInk.unread

    public var width = 0

    public var height = 0

    public var samples = 0

    public var mean = 0.0

    public var failure: String?

    public init() {}

    public var json: JSONValue {
        .object([
            "ink": .number(ink),
            "width": .integer(width),
            "height": .integer(height),
            "samples": .integer(samples),
            "mean": .number(mean),
            "failure": failure.map(JSONValue.string) ?? .null,
        ])
    }

    public static func of(_ image: CGImage) -> InkReading {
        var reading = InkReading()
        reading.width = image.width
        reading.height = image.height
        guard image.width > leastSide, image.height > leastSide else {
            reading.failure = "the capture came back \(image.width) by \(image.height)"
            return reading
        }
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            reading.failure = "the capture could not be drawn into a buffer to read"
            return reading
        }
        return count(pixels, bytesPerRow: bytesPerRow, into: reading)
    }

    private static func count(
        _ pixels: [UInt8], bytesPerRow: Int, into reading: InkReading
    ) -> InkReading {
        var reading = reading
        let stepX = max(1, reading.width / samplesAcross)
        let stepY = max(1, reading.height / samplesAcross)
        var edges = 0
        var samples = 0
        var total = 0.0
        for y in stride(from: 0, to: reading.height, by: stepY) {
            var previous: (Int, Int, Int)?
            for x in stride(from: 0, to: reading.width, by: stepX) {
                let offset = y * bytesPerRow + x * 4
                let found = (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
                total += Double(found.0 + found.1 + found.2) / (3 * 255)
                defer { previous = found }
                guard let previous else { continue }
                samples += 1
                let apart = abs(found.0 - previous.0) + abs(found.1 - previous.1)
                    + abs(found.2 - previous.2)
                if Double(apart) / 255 > Self.apart { edges += 1 }
            }
        }
        reading.samples = samples
        reading.ink = samples == 0 ? 0 : Double(edges) / Double(samples)
        reading.mean = samples == 0 ? 0 : total / Double(samples + 1)
        return reading
    }
}
