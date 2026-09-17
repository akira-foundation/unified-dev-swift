import Foundation

public enum ChatTextSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case standard
    case large
    case extraLarge
    case largest

    public static let defaultsKey = "chat.textSize"

    public static let defaultChoice: Self = .large

    public var id: String { rawValue }

    public var scale: CGFloat {
        switch self {
        case .small: 0.9
        case .standard: 1
        case .large: 1.15
        case .extraLarge: 1.3
        case .largest: 1.5
        }
    }

    public var title: String {
        switch self {
        case .small: "Smallest"
        case .standard: "Smaller"
        case .large: "Default"
        case .extraLarge: "Larger"
        case .largest: "Largest"
        }
    }
}

extension ChatTextSize {
    public static var current: ChatTextSize {
        get { read(from: .standard) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    public static func read(from defaults: UserDefaults) -> Self {
        defaults.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? defaultChoice
    }

    public func stepped(by offset: Int) -> ChatTextSize? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self) else { return nil }
        let moved = index + offset
        guard steps.indices.contains(moved) else { return nil }
        return steps[moved]
    }
}
