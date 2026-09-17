import SwiftUI
import CoreGraphics

@MainActor
enum ChartPaperTexture {
    static let tileSize = 256

    static let fieldWidth = 320
    static let fieldHeight = 200

    static let tile: CGImage = makeTile()

    static let field: CGImage = makeField()

    private static func makeTile() -> CGImage {
        let side = tileSize
        var grain = ChartGrain(seed: 0x9A17_E4D2)
        let fine = WrapNoise(cellsX: side, cellsY: side, grain: &grain)
        let fibre = WrapNoise(cellsX: side / 8, cellsY: side, grain: &grain)
        let weave = WrapNoise(cellsX: side / 3, cellsY: side / 3, grain: &grain)

        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            let v = (Double(y) + 0.5) / Double(side)
            for x in 0..<side {
                let u = (Double(x) + 0.5) / Double(side)
                let value = 0.52 * fine.sample(u, v)
                    + 0.34 * fibre.sample(u, v)
                    + 0.14 * weave.sample(u, v)
                let signed = (value - 0.5) * 2
                let index = (y * side + x) * 4
                if signed < 0 {
                    let alpha = min(1, -signed * 0.14)
                    pixels[index + 3] = UInt8(alpha * 255)
                } else {
                    let alpha = min(1, signed * 0.105)
                    let premultiplied = UInt8(alpha * 255)
                    pixels[index] = premultiplied
                    pixels[index + 1] = premultiplied
                    pixels[index + 2] = premultiplied
                    pixels[index + 3] = premultiplied
                }
            }
        }
        return image(from: pixels, width: side, height: side)
    }

    private static func makeField() -> CGImage {
        let width = fieldWidth
        let height = fieldHeight
        var grain = ChartGrain(seed: 0xB13D_7C05)
        let broad = WrapNoise(cellsX: 3, cellsY: 2, grain: &grain)
        let middle = WrapNoise(cellsX: 7, cellsY: 5, grain: &grain)
        let close = WrapNoise(cellsX: 16, cellsY: 11, grain: &grain)
        let damp = WrapNoise(cellsX: 6, cellsY: 4, grain: &grain)
        let dampDetail = WrapNoise(cellsX: 13, cellsY: 9, grain: &grain)
        let dampEdge = WrapNoise(cellsX: 27, cellsY: 18, grain: &grain)
        let warpX = WrapNoise(cellsX: 5, cellsY: 4, grain: &grain)
        let warpY = WrapNoise(cellsX: 4, cellsY: 5, grain: &grain)

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let v = (Double(y) + 0.5) / Double(height)
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width)
                let formation = (0.5 * broad.sample(u, v)
                    + 0.32 * middle.sample(u, v)
                    + 0.18 * close.sample(u, v) - 0.5) * 2

                let warpedU = u + (warpX.sample(u, v) - 0.5) * 0.14
                let warpedV = v + (warpY.sample(u, v) - 0.5) * 0.14
                let wet = 0.62 * damp.sample(warpedU, warpedV)
                    + 0.26 * dampDetail.sample(warpedU, warpedV)
                    + 0.12 * dampEdge.sample(warpedU, warpedV)
                let shore = 0.615
                let body = smoothstep(shore, shore + 0.16, wet) * 0.85
                let tideline = exp(-pow((wet - shore - 0.010) / 0.030, 2)) * 0.48
                let stained = min(body + tideline, 1.2)

                var red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0
                if formation < 0 {
                    let a = -formation * 0.085
                    red += 0.29 * a; green += 0.22 * a; blue += 0.13 * a; alpha += a
                } else {
                    let a = formation * 0.055
                    red += a; green += a; blue += 0.94 * a; alpha += a
                }
                if stained > 0 {
                    let a = stained * 0.085
                    red += 0.54 * a; green += 0.38 * a; blue += 0.18 * a; alpha += a
                }
                let index = (y * width + x) * 4
                pixels[index] = UInt8(min(red, 1) * 255)
                pixels[index + 1] = UInt8(min(green, 1) * 255)
                pixels[index + 2] = UInt8(min(blue, 1) * 255)
                pixels[index + 3] = UInt8(min(alpha, 1) * 255)
            }
        }
        return image(from: pixels, width: width, height: height)
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ value: Double) -> Double {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func image(from pixels: [UInt8], width: Int, height: Int) -> CGImage {
        var pixels = pixels
        let made: CGImage? = pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )?.makeImage()
        }
        return made ?? blankImage()
    }

    private static func blankImage() -> CGImage {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return context!.makeImage()!
    }
}

struct WrapNoise {
    private let cellsX: Int
    private let cellsY: Int
    private let values: [Double]

    init(cellsX: Int, cellsY: Int, grain: inout ChartGrain) {
        self.cellsX = max(1, cellsX)
        self.cellsY = max(1, cellsY)
        var values: [Double] = []
        values.reserveCapacity(self.cellsX * self.cellsY)
        for _ in 0..<(self.cellsX * self.cellsY) { values.append(grain.next()) }
        self.values = values
    }

    func sample(_ u: Double, _ v: Double) -> Double {
        let x = u * Double(cellsX)
        let y = v * Double(cellsY)
        let xFloor = x.rounded(.down)
        let yFloor = y.rounded(.down)
        let fx = smooth(x - xFloor)
        let fy = smooth(y - yFloor)
        let x0 = wrap(Int(xFloor), cellsX)
        let y0 = wrap(Int(yFloor), cellsY)
        let x1 = (x0 + 1) % cellsX
        let y1 = (y0 + 1) % cellsY
        let top = values[y0 * cellsX + x0] + (values[y0 * cellsX + x1] - values[y0 * cellsX + x0]) * fx
        let bottom = values[y1 * cellsX + x0] + (values[y1 * cellsX + x1] - values[y1 * cellsX + x0]) * fx
        return top + (bottom - top) * fy
    }

    private func wrap(_ value: Int, _ count: Int) -> Int {
        let remainder = value % count
        return remainder < 0 ? remainder + count : remainder
    }

    private func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
}

struct ChartGrain {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
