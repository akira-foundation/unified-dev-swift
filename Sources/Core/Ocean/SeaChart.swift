import Foundation

public enum SeaChartProjection {
    public static let aspectRatio = 2.0

    public static func unitPoint(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        ((longitude + 180) / 360, (90 - latitude) / 180)
    }

    public static func markPoint(
        latitude: Double, longitude: Double,
        inX x: Double, y: Double, width: Double, height: Double, inset: Double
    ) -> (x: Double, y: Double) {
        let unit = unitPoint(latitude: latitude, longitude: longitude)
        let clampedInset = min(inset, width / 2, height / 2)
        return (
            min(max(x + unit.x * width, x + clampedInset), x + width - clampedInset),
            min(max(y + unit.y * height, y + clampedInset), y + height - clampedInset)
        )
    }

    public static func mapRect(
        fittingWidth width: Double, height: Double, margin: Double
    ) -> (x: Double, y: Double, width: Double, height: Double) {
        let availableWidth = max(0, width - margin * 2)
        let availableHeight = max(0, height - margin * 2)
        let mapWidth = min(availableWidth, availableHeight * aspectRatio)
        let mapHeight = mapWidth / aspectRatio
        return ((width - mapWidth) / 2, (height - mapHeight) / 2, mapWidth, mapHeight)
    }
}

public enum SeaChartCoast {
    public static let rings: [[(x: Double, y: Double)]] = parse(builtInRings)

    public static func parse(_ encoded: String) -> [[(x: Double, y: Double)]] {
        encoded.components(separatedBy: .newlines).compactMap { line in
            let ring: [(x: Double, y: Double)] = line.split(separator: " ").compactMap { pair in
                let parts = pair.split(separator: ",")
                guard parts.count == 2,
                      let longitude = Double(parts[0]), let latitude = Double(parts[1]),
                      (-90.0...90.0).contains(latitude),
                      (-180.0...180.0).contains(longitude) else { return nil }
                return SeaChartProjection.unitPoint(latitude: latitude, longitude: longitude)
            }
            return ring.count >= 3 ? ring : nil
        }
    }
}

public struct SeaChartLabel: Sendable, Equatable {
    public let mark: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(mark: Int, x: Double, y: Double, width: Double, height: Double) {
        self.mark = mark
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    func intersects(_ other: SeaChartLabel) -> Bool {
        x < other.x + other.width && other.x < x + width
            && y < other.y + other.height && other.y < y + height
    }
}

public enum SeaChartLabels {
    static let gap = 2.0

    public static func place(
        marks: [(x: Double, y: Double)],
        sizes: [(width: Double, height: Double)],
        markRadius: Double,
        boundsX: Double, boundsY: Double, boundsWidth: Double, boundsHeight: Double,
        reserved: [(x: Double, y: Double, width: Double, height: Double)] = []
    ) -> [SeaChartLabel] {
        var placed: [SeaChartLabel] = []
        let blocked = reserved.map {
            SeaChartLabel(mark: -1, x: $0.x, y: $0.y, width: $0.width, height: $0.height)
        }
        for (index, mark) in marks.enumerated() {
            guard index < sizes.count else { break }
            let size = sizes[index]
            let offset = markRadius + gap
            let candidates: [(Double, Double)] = [
                (mark.x + offset, mark.y - size.height / 2),
                (mark.x - offset - size.width, mark.y - size.height / 2),
                (mark.x - size.width / 2, mark.y - offset - size.height),
                (mark.x - size.width / 2, mark.y + offset),
            ]
            for (x, y) in candidates {
                let candidate = SeaChartLabel(
                    mark: index, x: x, y: y, width: size.width, height: size.height
                )
                guard x >= boundsX, y >= boundsY,
                      x + size.width <= boundsX + boundsWidth,
                      y + size.height <= boundsY + boundsHeight else { continue }
                guard !placed.contains(where: { $0.intersects(candidate) }) else { continue }
                guard !blocked.contains(where: { $0.intersects(candidate) }) else { continue }
                let coversMark = marks.enumerated().contains { otherIndex, other in
                    otherIndex != index
                        && other.x + markRadius > x && other.x - markRadius < x + size.width
                        && other.y + markRadius > y && other.y - markRadius < y + size.height
                }
                guard !coversMark else { continue }
                placed.append(candidate)
                break
            }
        }
        return placed
    }
}

public struct SeaChartCamera: Sendable, Equatable {
    public static let minimumScale = 1.0
    public static let maximumScale = 10.0

    public let scale: Double
    public let centerX: Double
    public let centerY: Double

    public static let whole = SeaChartCamera(scale: minimumScale, centerX: 0.5, centerY: 0.5)

    public init(scale: Double, centerX: Double, centerY: Double) {
        let bounded = min(max(scale.isFinite ? scale : Self.minimumScale, Self.minimumScale), Self.maximumScale)
        let half = 0.5 / bounded
        self.scale = bounded
        self.centerX = min(max(centerX.isFinite ? centerX : 0.5, half), 1 - half)
        self.centerY = min(max(centerY.isFinite ? centerY : 0.5, half), 1 - half)
    }

    public var isWholeWorld: Bool { scale <= Self.minimumScale + 1e-9 }

    public var visibleRegion: (x: Double, y: Double, width: Double, height: Double) {
        let side = 1 / scale
        return (centerX - side / 2, centerY - side / 2, side, side)
    }

    public func zoomed(by factor: Double, aroundUnitX x: Double, unitY y: Double) -> SeaChartCamera {
        guard factor.isFinite, factor > 0 else { return self }
        let target = min(max(scale * factor, Self.minimumScale), Self.maximumScale)
        let before = visibleRegion
        let fractionX = before.width > 0 ? (x - before.x) / before.width : 0.5
        let fractionY = before.height > 0 ? (y - before.y) / before.height : 0.5
        let side = 1 / target
        return SeaChartCamera(
            scale: target,
            centerX: x - fractionX * side + side / 2,
            centerY: y - fractionY * side + side / 2
        )
    }

    public func panned(byUnitX x: Double, unitY y: Double) -> SeaChartCamera {
        SeaChartCamera(scale: scale, centerX: centerX + x, centerY: centerY + y)
    }
}

extension SeaChartProjection {
    public static func worldRect(
        inX x: Double, y: Double, width: Double, height: Double, camera: SeaChartCamera
    ) -> (x: Double, y: Double, width: Double, height: Double) {
        let worldWidth = width * camera.scale
        let worldHeight = height * camera.scale
        return (
            x + width / 2 - camera.centerX * worldWidth,
            y + height / 2 - camera.centerY * worldHeight,
            worldWidth,
            worldHeight
        )
    }
}

extension SeaChartLabels {
    public static func fontSize(forMapWidth width: Double) -> Double {
        min(max(width / 62, 11.5), 19)
    }
}

extension SeaChartProjection {
    public static func defaultWindowSize(
        screenWidth: Double, screenHeight: Double,
        margin: Double, footerHeight: Double, fraction: Double = 0.8
    ) -> (width: Double, height: Double) {
        let budgetWidth = max(0, screenWidth * fraction)
        let budgetHeight = max(0, screenHeight * fraction)
        let sheet = mapRect(
            fittingWidth: budgetWidth,
            height: max(0, budgetHeight - footerHeight),
            margin: margin
        )
        return (
            max(480, sheet.width + margin * 2),
            max(360, sheet.height + margin * 2 + footerHeight)
        )
    }
}
