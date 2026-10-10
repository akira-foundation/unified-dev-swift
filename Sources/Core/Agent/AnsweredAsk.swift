import Foundation

public enum AnsweredAsk {
    public static func payload(of payload: Data, answers: [String: String]) -> Data? {
        guard !answers.isEmpty,
              let parsed = JSONValue.parse(payload),
              case .object(var envelope) = parsed,
              case .object(var request)? = envelope["request"]
        else {
            return nil
        }

        let input = request["input"] ?? .object([:])
        let answered = AgentQuestionnaire.answered(input, answers: answers)

        guard answered != input else { return nil }

        request["input"] = answered
        envelope["request"] = .object(request)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try? encoder.encode(JSONValue.object(envelope))
    }

    public static func answers(in payload: Data) -> [String: String] {
        guard let json = JSONValue.parse(payload), let input = json["request"]?["input"] else {
            return [:]
        }
        return AgentQuestionnaire.answers(in: input)
    }
}
