import Core

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
