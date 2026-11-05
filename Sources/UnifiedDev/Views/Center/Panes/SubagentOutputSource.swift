import Foundation
import Core

@MainActor
struct SubagentOutputSource {
    var model: WorkspaceModel
    var target: SubagentRunLink.Target
    var source: TranscriptModel?

    var transcript: TranscriptModel? { source ?? model.activeTranscript }

    var subagent: Subagent? {
        let roster = transcript?.subagents
        switch target {
        case let .live(id):
            return roster?.task(id)
        case let .recorded(toolUseID):
            return roster?.subagent(forToolUseID: toolUseID)
                ?? model.recordedSubagent(forToolUseID: toolUseID, in: transcript)
        case .unavailable:
            return nil
        }
    }

    func follow(_ deliver: @MainActor (Result<SubagentReading, SubagentOutput.Failure>) -> Void) async {
        await load(deliver)
        while !Task.isCancelled, SubagentPane.refreshes(subagent) {
            try? await Task.sleep(for: .seconds(SubagentPane.refreshSeconds))
            guard !Task.isCancelled else { return }
            await load(deliver)
        }
        await load(deliver)
    }

    private func load(_ deliver: @MainActor (Result<SubagentReading, SubagentOutput.Failure>) -> Void) async {
        let result = await read()
        guard !Task.isCancelled else { return }
        deliver(result)
    }

    private func read() async -> Result<SubagentReading, SubagentOutput.Failure> {
        if case let .live(id) = target,
           let parsed = await transcript?.codexSubagentTranscript(for: id) {
            return .success(await Task.detached { SubagentReading(parsed) }.value)
        }
        let path = subagent?.outputFile
        let kind = subagent?.kind ?? .agent
        let session = transcript?.session.id ?? SessionID("")
        let toolUseID = subagent?.toolUseID ?? ""
        let lines = kind == .agent ? model.subagentStreamLines(forToolUseID: toolUseID, in: transcript) : []
        return await Task.detached { () -> Result<SubagentReading, SubagentOutput.Failure> in
            switch SubagentOutput.read(path: path, kind: kind, sessionID: session) {
            case .success(let parsed):
                return .success(SubagentReading(parsed))
            case .failure(let reason):
                let live = SubagentTranscript.live(streamLines: lines, sessionID: session)
                return live.isEmpty ? .failure(reason) : .success(SubagentReading(live))
            }
        }.value
    }
}
