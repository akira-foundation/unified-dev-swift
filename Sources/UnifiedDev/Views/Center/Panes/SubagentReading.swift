import Core

struct SubagentOutputState: Equatable {
    private(set) var reading = SubagentReading()
    private(set) var failure: SubagentOutput.Failure?
    private(set) var hasRead = false

    mutating func apply(_ result: Result<SubagentReading, SubagentOutput.Failure>) {
        hasRead = true
        switch result {
        case .success(let parsed):
            reading = parsed
            failure = nil
        case .failure(let reason):
            reading = SubagentReading()
            failure = reason
        }
    }
}

struct SubagentReading: Equatable, Sendable {
    var rows: [TranscriptRow] = []
    var droppedRows = 0
    var printed = ""
    var prompt = ""

    init() {}

    init(_ transcript: SubagentTranscript) {
        rows = TranscriptModel.rows(from: transcript.messages)
        droppedRows = transcript.droppedRows
        printed = transcript.printed
        prompt = transcript.prompt
    }
}
