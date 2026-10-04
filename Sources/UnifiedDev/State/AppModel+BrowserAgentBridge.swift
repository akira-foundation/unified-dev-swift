import Core

extension AppModel {
    private static let pollInterval = 100

    func outlinePage(
        on session: BrowserSession, report: BrowserPaneReport
    ) async -> BrowserPaneAnswer {
        if let trouble = report.trouble {
            return .told(
                trouble + " There is nothing on the page to point at. browser_read carries the "
                    + "same fact, and browser_reload tries again."
            )
        }
        do {
            let answer = try await session.callAgentScript(.outline)
            guard let json = (answer as? String)?.data(using: .utf8) else {
                return .refused(BrowserScriptFailure().localizedDescription)
            }
            let elements = try BrowserPageOutline.decode(json)
            session.agentHandles.recorded(count: elements.count)
            return .told(BrowserPageOutline.render(elements, from: report.address))
        } catch {
            return .refused(error.readableMessage)
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
            let met: Bool
            do {
                let answer = try await session.callAgentScript(script)
                met = (answer as? [String])?.first == "met"
            } catch {
                return .refused(error.readableMessage)
            }
            let waited = Int(started.duration(to: .now) / .milliseconds(1))
            guard !met else { return .told(said(true, condition, waited, seconds)) }
            guard ContinuousClock.now < deadline else {
                return .told(said(false, condition, waited, seconds))
            }
            try? await Task.sleep(for: .milliseconds(Self.pollInterval))
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
