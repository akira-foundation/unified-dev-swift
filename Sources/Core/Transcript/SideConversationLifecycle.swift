import Foundation

public struct SideConversationLifecycle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case opening(generation: Int)
        case open(SessionID)
    }

    public struct Arrival: Equatable, Sendable {
        public var quotes: [String]
        public var question: String
    }

    public struct Opening: Equatable, Sendable {
        public var generation: Int
        public var keeping: SessionID?
    }

    public enum Start: Equatable, Sendable {
        case wait
        case resume(SessionID, Arrival)
        case open(Opening)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var isShown = false
    public private(set) var pendingQuotes: [String] = []
    public private(set) var pendingQuestion = ""
    private var generation = 0

    public init() {}

    public var isOpening: Bool {
        if case .opening = phase { return true }
        return false
    }

    public var sessionID: SessionID? {
        if case .open(let id) = phase { return id }
        return nil
    }

    public mutating func start(question: String = "", quoting: String = "", fresh: Bool = false) -> Start {
        isShown = true
        if !quoting.isEmpty { pendingQuotes.append(quoting) }
        if !question.isEmpty { pendingQuestion = question }
        switch phase {
        case .opening:
            return .wait
        case .open(let id) where !fresh:
            return .resume(id, takeArrival())
        case .open(let id):
            return .open(beginOpening(keeping: id))
        case .idle:
            return .open(beginOpening(keeping: nil))
        }
    }

    public mutating func opened(_ id: SessionID, generation: Int) -> Arrival? {
        guard phase == .opening(generation: generation) else { return nil }
        phase = .open(id)
        return takeArrival()
    }

    public mutating func failed(generation: Int) {
        guard phase == .opening(generation: generation) else { return }
        phase = .idle
        pendingQuotes = []
        pendingQuestion = ""
    }

    public mutating func hide() {
        isShown = false
    }

    public mutating func close() -> SessionID? {
        end()
    }

    public mutating func keep() -> SessionID? {
        guard case .open = phase else { return nil }
        return end()
    }

    private mutating func end() -> SessionID? {
        let ending = sessionID
        generation += 1
        phase = .idle
        isShown = false
        pendingQuotes = []
        pendingQuestion = ""
        return ending
    }

    private mutating func beginOpening(keeping: SessionID?) -> Opening {
        generation += 1
        phase = .opening(generation: generation)
        return Opening(generation: generation, keeping: keeping)
    }

    private mutating func takeArrival() -> Arrival {
        defer { pendingQuotes = []; pendingQuestion = "" }
        return Arrival(quotes: pendingQuotes, question: pendingQuestion)
    }
}
