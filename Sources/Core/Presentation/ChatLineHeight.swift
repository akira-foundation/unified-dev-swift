import Foundation

public enum ChatLineHeight: String, CaseIterable, Identifiable, Sendable {
    case tightest
    case tighter
    case standard
    case looser
    case loosest

    public static let defaultsKey = "chat.lineHeight"

    public static let defaultChoice: Self = .tighter

    public var id: String { rawValue }

    public var ratio: Double {
        switch self {
        case .tightest: 1.4
        case .tighter: 1.55
        case .standard: 1.7
        case .looser: 1.85
        case .loosest: 2
        }
    }

    public var listRatio: Double {
        1.3 + (ratio - 1.4) / 2
    }

    public var title: String {
        switch self {
        case .tightest: "Tight"
        case .tighter: "Default"
        case .standard: "Loose"
        case .looser: "Looser"
        case .loosest: "Loosest"
        }
    }
}

extension ChatLineHeight {
    public static var current: ChatLineHeight {
        get { read(from: .standard) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    public static func read(from defaults: UserDefaults) -> Self {
        defaults.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? defaultChoice
    }
}
