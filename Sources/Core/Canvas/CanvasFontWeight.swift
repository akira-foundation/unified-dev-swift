import Foundation

public enum CanvasFontWeight: Sendable, CaseIterable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

    public var value: Double {
        switch self {
        case .ultraLight: -0.8
        case .thin: -0.6
        case .light: -0.4
        case .regular: 0
        case .medium: 0.23
        case .semibold: 0.3
        case .bold: 0.4
        case .heavy: 0.56
        case .black: 0.62
        }
    }

    public static func nearest(to value: Double) -> CanvasFontWeight {
        allCases.min { abs($0.value - value) < abs($1.value - value) } ?? .regular
    }
}
