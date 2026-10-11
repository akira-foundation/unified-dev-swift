import Foundation

extension PreviewScenarioSeeder {
    public func seedTranscripts(
        _ scenario: PreviewScenario,
        at now: Date,
        home: URL?,
        calendar: Calendar = .current
    ) throws -> Int {
        guard !scenario.transcripts.isEmpty else { return 0 }
        guard let home else { throw PreviewScenarioError.notAPreview }

        try clear(home)
        var written = 0
        for (index, transcript) in scenario.transcripts.enumerated() {
            let url = try place(transcript, index: index, in: home, at: now, calendar: calendar)
            let body = lines(of: transcript, at: now, calendar: calendar).joined(separator: "\n") + "\n"
            try Data(cut(body, ifTruncated: transcript.truncated).utf8).write(to: url)
            written += 1
        }
        return written
    }

    public func transcriptDirectory(of transcript: PreviewScenario.Transcript) -> String {
        guard let project = transcript.project else { return scratchRoot + "/elsewhere" }
        return projectsRoot + "/" + project
    }

    private func clear(_ home: URL) throws {
        for leaf in [".claude/projects", ".codex/sessions"] {
            let directory = home.appending(path: leaf)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func cut(_ body: String, ifTruncated truncated: Bool) -> String {
        guard truncated else { return body }
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
        guard let last = lines.last, lines.count > 1 else { return body }
        return (lines.dropLast().joined(separator: "\n") + "\n")
            + String(last.prefix(last.count - PreviewScenario.Transcript.truncationBite))
    }

    private func place(
        _ transcript: PreviewScenario.Transcript,
        index: Int,
        in home: URL,
        at now: Date,
        calendar: Calendar
    ) throws -> URL {
        let directory: URL
        let name: String
        let day = stamp(daysAgo: transcript.daysAgo, from: now, calendar: calendar)
        switch transcript.provider {
        case .codex:
            directory = home.appending(path: ".codex/sessions/\(day.year)/\(day.month)/\(day.day)")
            name = "rollout-\(day.year)-\(day.month)-\(day.day)T09-00-00-preview-\(index)"
                + "-0000-0000-00000000000\(index % 10).jsonl"
        default:
            let slug = transcriptDirectory(of: transcript).replacingOccurrences(of: "/", with: "-")
            directory = home.appending(path: ".claude/projects/\(slug)")
            name = "preview-session-\(index).jsonl"
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: name)
    }

    private func lines(
        of transcript: PreviewScenario.Transcript,
        at now: Date,
        calendar: Calendar
    ) -> [String] {
        let moment = iso(daysAgo: transcript.daysAgo, from: now, calendar: calendar)
        let directory = quoted(transcriptDirectory(of: transcript))
        let model = quoted(transcript.model)
        let filler = String(repeating: "x", count: transcript.padding)
        switch transcript.provider {
        case .codex:
            return [codexContext(model: model, directory: directory, at: moment)]
                + (0..<transcript.turns).map { turn in
                    codexCount(turn: turn, at: moment, filler: filler)
                }
        default:
            return (0..<transcript.turns).map { turn in
                claudeTurn(model: model, directory: directory, at: moment, turn: turn, filler: filler)
            }
        }
    }

    private func quoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func claudeTurn(
        model: String,
        directory: String,
        at moment: String,
        turn: Int,
        filler: String
    ) -> String {
        """
        {"type":"assistant","timestamp":"\(moment)","cwd":"\(directory)",\
        "isSidechain":false,"filler":"\(filler)",\
        "message":{"role":"assistant","id":"msg_preview_\(moment)_\(turn)",\
        "content":[{"type":"text","text":"a preview turn"}],\
        "model":"\(model)","usage":{"input_tokens":\(120 + turn),"output_tokens":\(900 + turn * 7),\
        "cache_read_input_tokens":\(420_000 + turn * 1_100),"cache_creation_input_tokens":\(11_000 + turn),\
        "cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":\(11_000 + turn)},\
        "service_tier":"standard"}}}
        """
    }

    private func codexContext(model: String, directory: String, at moment: String) -> String {
        """
        {"timestamp":"\(moment)","ordinal":1,"type":"turn_context",\
        "payload":{"turn_id":"preview","cwd":"\(directory)","model":"\(model)","effort":"high"}}
        """
    }

    private func codexCount(turn: Int, at moment: String, filler: String) -> String {
        """
        {"timestamp":"\(moment)","ordinal":\(turn + 2),"type":"event_msg",\
        "payload":{"type":"token_count","filler":"\(filler)","info":{"last_token_usage":\
        {"input_tokens":\(90_000 + turn * 40),"cached_input_tokens":\(88_000 + turn * 30),\
        "cache_write_input_tokens":0,"output_tokens":\(300 + turn),"reasoning_output_tokens":\(90 + turn)}}}}
        """
    }

    private func iso(daysAgo: Int, from now: Date, calendar: Calendar) -> String {
        let day = stamp(daysAgo: daysAgo, from: now, calendar: calendar)
        let offset = calendar.timeZone.secondsFromGMT(for: now)
        let sign = offset < 0 ? "-" : "+"
        let minutes = abs(offset) / 60
        return "\(day.year)-\(day.month)-\(day.day)T12:00:00.000"
            + sign + String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func stamp(
        daysAgo: Int,
        from now: Date,
        calendar: Calendar
    ) -> (year: String, month: String, day: String) {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (
            String(format: "%04d", parts.year ?? 2026),
            String(format: "%02d", parts.month ?? 1),
            String(format: "%02d", parts.day ?? 1)
        )
    }
}
