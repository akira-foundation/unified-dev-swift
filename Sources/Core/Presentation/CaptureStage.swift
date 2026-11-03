import Foundation

public enum CaptureStageReading: Sendable, Equatable {
    case stage(CaptureStage)
    case refused(String)
}

public enum CaptureStage: String, CaseIterable, Sendable {
    case window
    case createWorkspace = "create-workspace"
    case review
    case agentChoice = "agent-choice"
    case terminal
    case browser
    case spend

    public static var names: String {
        allCases.map { "'\($0.rawValue)'" }.joined(separator: ", ")
    }

    public static func reading(_ raw: String?, asked: Bool = true) -> CaptureStageReading {
        guard asked else { return .stage(.window) }
        guard let raw else {
            return .refused("--stage needs a name. Unified Dev stages \(names).")
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .refused("--stage needs a name. Unified Dev stages \(names).")
        }
        guard let stage = CaptureStage(rawValue: trimmed) else {
            return .refused("Unified Dev has no capture stage called '\(trimmed)'. It stages \(names).")
        }
        return .stage(stage)
    }

    public func refusal(inAPreview: Bool) -> String? {
        guard self != .window, !inAPreview else { return nil }
        return "--stage \(rawValue) arranges the app before it is photographed, and arranging it "
            + "means discarding drafts, writing preferences and starting a shell. It runs in a "
            + "preview and nowhere else. This copy is not one."
    }

    public var opensItsOwnWindow: Bool { self == .spend }

    public var opensAPopover: Bool {
        switch self {
        case .createWorkspace, .agentChoice: true
        case .window, .review, .terminal, .browser, .spend: false
        }
    }

    public var canBeParkedOffscreen: Bool { !opensAPopover }

    public var isArrangedInTheWindow: Bool {
        switch self {
        case .createWorkspace, .review, .agentChoice, .terminal, .browser: true
        case .window, .spend: false
        }
    }

    public var arrangesTheWorkspace: Bool {
        switch self {
        case .review, .agentChoice, .terminal, .browser: true
        case .window, .createWorkspace, .spend: false
        }
    }
}
