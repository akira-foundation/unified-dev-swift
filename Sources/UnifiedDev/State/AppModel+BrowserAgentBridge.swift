import Core

extension AppModel {
    func outlinePage(
        on session: BrowserSession, report: BrowserPaneReport
    ) async -> BrowserPaneAnswer {
        if let trouble = report.trouble {
            return .told(BrowserPageOutline.troubled(trouble))
        }
        let answer: Any?
        do {
            answer = try await session.callAgentScript(.outline)
        } catch {
            session.agentHandles.pageChanged()
            return .refused(error.readableMessage)
        }
        switch BrowserPageOutline.survey(answer) {
        case .failure(let refusal):
            session.agentHandles.pageChanged()
            return .refused(refusal.sentence)
        case .success(let survey):
            session.agentHandles.recorded(count: survey.elements.count)
            return .told(BrowserPageOutline.render(survey, from: report.address))
        }
    }

    func actInPage(
        _ script: BrowserAgentScript, on session: BrowserSession, tool: String
    ) async -> BrowserPaneAnswer {
        if let reference = script.reference,
           let refusal = session.agentHandles.refusal(for: reference, tool: tool) {
            return .refused(refusal)
        }
        do {
            let answer = try await session.callAgentScript(script)
            switch BrowserAgentOutcome.acted(answer as? [String] ?? [], for: script) {
            case .success(let sentence): return .told(sentence)
            case .failure(let refusal): return .refused(refusal.sentence)
            }
        } catch {
            return .refused(error.readableMessage)
        }
    }

    func waitInPage(
        _ condition: BrowserWaitCondition, seconds: Int, on session: BrowserSession
    ) async -> BrowserPaneAnswer {
        let started = ContinuousClock.now
        let deadline = started + .seconds(seconds)
        let script = BrowserAgentScript.settled(condition)
        while !Task.isCancelled {
            let reading: BrowserWaitReading
            do {
                let answer = try await session.callAgentScript(script)
                reading = BrowserAgentOutcome.read(answer as? [String] ?? [])
            } catch {
                return .refused(error.readableMessage)
            }
            guard reading != .unreadable else { return .refused(BrowserWaitReading.sentence) }
            let waited = Int(started.duration(to: .now) / .milliseconds(1))
            guard reading != .met else { return .told(said(true, condition, waited, seconds)) }
            guard ContinuousClock.now < deadline else {
                return .told(said(false, condition, waited, seconds))
            }
            try? await Task.sleep(for: .milliseconds(BrowserWaitReading.pollMilliseconds))
        }
        return .refused("Unified Dev stopped waiting on this page before the time was up.")
    }

    private func said(
        _ met: Bool, _ condition: BrowserWaitCondition, _ waited: Int, _ seconds: Int
    ) -> String {
        BrowserAgentOutcome.waited(
            met: met, for: condition, after: waited, ceiling: seconds
        )
    }
}
