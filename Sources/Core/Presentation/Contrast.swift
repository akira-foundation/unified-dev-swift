import Foundation

public enum Contrast {
    public static let textFloor = 4.5
    public static let largeTextFloor = 3.0
    public static let nonTextFloor = 3.0

    static func channels(of colour: UInt32) -> (r: UInt32, g: UInt32, b: UInt32) {
        ((colour >> 16) & 0xFF, (colour >> 8) & 0xFF, colour & 0xFF)
    }

    private static func linear(_ channel: UInt32) -> Double {
        let value = Double(channel) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    public static func relativeLuminance(of colour: UInt32) -> Double {
        let (r, g, b) = channels(of: colour)
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    public static func ratio(_ one: UInt32, _ other: UInt32) -> Double {
        let a = relativeLuminance(of: one)
        let b = relativeLuminance(of: other)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    public static func lab(of colour: UInt32) -> (l: Double, a: Double, b: Double) {
        let channels = channels(of: colour)
        let r = linear(channels.r)
        let g = linear(channels.g)
        let b = linear(channels.b)

        let x = (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
        let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        let z = (r * 0.0193339 + g * 0.1191920 + b * 0.9503041) / 1.08883

        func f(_ t: Double) -> Double {
            t > 216.0 / 24389 ? cbrt(t) : (841.0 / 108) * t + 4.0 / 29
        }
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    public static func deltaE(_ one: UInt32, _ other: UInt32) -> Double {
        deltaE(lab(of: one), lab(of: other))
    }

    public static func deltaE(
        _ one: (l: Double, a: Double, b: Double), _ other: (l: Double, a: Double, b: Double)
    ) -> Double {
        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
        func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
        func hue(_ a: Double, _ b: Double) -> Double {
            guard a != 0 || b != 0 else { return 0 }
            let value = degrees(atan2(b, a))
            return value < 0 ? value + 360 : value
        }

        let chroma1 = (one.a * one.a + one.b * one.b).squareRoot()
        let chroma2 = (other.a * other.a + other.b * other.b).squareRoot()
        let meanChroma = (chroma1 + chroma2) / 2
        let seventh = pow(meanChroma, 7)
        let stretch = 0.5 * (1 - (seventh / (seventh + pow(25, 7))).squareRoot())

        let a1 = (1 + stretch) * one.a
        let a2 = (1 + stretch) * other.a
        let c1 = (a1 * a1 + one.b * one.b).squareRoot()
        let c2 = (a2 * a2 + other.b * other.b).squareRoot()
        let h1 = hue(a1, one.b)
        let h2 = hue(a2, other.b)

        let deltaL = other.l - one.l
        let deltaC = c2 - c1
        var deltah = 0.0
        if c1 * c2 != 0 {
            deltah = h2 - h1
            if deltah > 180 { deltah -= 360 } else if deltah < -180 { deltah += 360 }
        }
        let deltaH = 2 * (c1 * c2).squareRoot() * sin(radians(deltah) / 2)

        let meanL = (one.l + other.l) / 2
        let meanC = (c1 + c2) / 2
        var meanH = h1 + h2
        if c1 * c2 != 0 {
            let sum = h1 + h2
            if abs(h1 - h2) <= 180 {
                meanH = sum / 2
            } else {
                meanH = sum < 360 ? (sum + 360) / 2 : (sum - 360) / 2
            }
        }

        let t = 1
            - 0.17 * cos(radians(meanH - 30))
            + 0.24 * cos(radians(2 * meanH))
            + 0.32 * cos(radians(3 * meanH + 6))
            - 0.20 * cos(radians(4 * meanH - 63))
        let meanSeventh = pow(meanC, 7)
        let rotationChroma = 2 * (meanSeventh / (meanSeventh + pow(25, 7))).squareRoot()
        let rotation = -sin(radians(2 * (30 * exp(-pow((meanH - 275) / 25, 2))))) * rotationChroma

        let weightL = 1 + (0.015 * pow(meanL - 50, 2)) / (20 + pow(meanL - 50, 2)).squareRoot()
        let weightC = 1 + 0.045 * meanC
        let weightH = 1 + 0.015 * meanC * t

        let lightness = deltaL / weightL
        let chroma = deltaC / weightC
        let hueTerm = deltaH / weightH
        return (
            lightness * lightness + chroma * chroma + hueTerm * hueTerm
                + rotation * chroma * hueTerm
        ).squareRoot()
    }

    public static func composited(_ colour: UInt32, over background: UInt32, at alpha: Double) -> UInt32 {
        let alpha = min(max(alpha, 0), 1)
        var result: UInt32 = 0
        for shift in [16, 8, 0] as [UInt32] {
            let front = Double((colour >> shift) & 0xFF)
            let back = Double((background >> shift) & 0xFF)
            let mixed = UInt32((front * alpha + back * (1 - alpha)).rounded())
            result |= min(mixed, 255) << shift
        }
        return result
    }
}
