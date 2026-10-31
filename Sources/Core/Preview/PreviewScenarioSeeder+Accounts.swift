import Foundation

extension PreviewScenarioSeeder {
    public func seedAgentAccounts(
        _ scenario: PreviewScenario,
        home: URL?,
        at now: Date
    ) throws -> Int {
        guard !scenario.accounts.isEmpty else { return 0 }
        guard let home else { throw PreviewScenarioError.noTranscriptHome }

        var written = 0
        for account in scenario.accounts {
            guard let place = AgentAccountHome.defaultHome(for: account.provider, home: home) else { continue }
            try FileManager.default.createDirectory(
                at: place.directory, withIntermediateDirectories: true
            )
            for (url, body) in files(of: account, at: place, expiring: now) {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try Data(body.utf8).write(to: url)
            }
            written += 1
        }
        return written
    }

    private func files(
        of account: PreviewScenario.Account,
        at place: AgentAccountHome,
        expiring now: Date
    ) -> [(URL, String)] {
        let expiry = now.addingTimeInterval(60 * 60 * 24 * 30)
        switch account.provider {
        case .codex:
            return [(place.credentialPath, codexAuth(account, expiring: expiry))]
        default:
            return [
                (place.identityPath, claudeIdentity(account)),
                (place.credentialPath, claudeCredential(account, expiring: expiry)),
            ]
        }
    }

    private func claudeIdentity(_ account: PreviewScenario.Account) -> String {
        let members = [
            "\"emailAddress\":\"\(escaped(account.email))\"",
            "\"displayName\":\"\(escaped(account.displayName ?? account.email))\"",
            "\"organizationName\":\"\(escaped(account.organisation ?? "Preview"))\"",
        ]
        return "{\"oauthAccount\":{" + members.joined(separator: ",") + "}}"
    }

    private func claudeCredential(_ account: PreviewScenario.Account, expiring: Date) -> String {
        let subscription = (account.plan ?? "max").lowercased().replacingOccurrences(of: " ", with: "_")
        return "{\"claudeAiOauth\":{\"subscriptionType\":\"\(escaped(subscription))\","
            + "\"expiresAt\":\(Int(expiring.timeIntervalSince1970 * 1000))}}"
    }

    private func codexAuth(_ account: PreviewScenario.Account, expiring: Date) -> String {
        let claims = "{\"email\":\"\(escaped(account.email))\","
            + "\"name\":\"\(escaped(account.displayName ?? account.email))\","
            + "\"exp\":\(Int(expiring.timeIntervalSince1970)),"
            + "\"https://api.openai.com/auth\":{\"chatgpt_plan_type\":\"\(escaped(account.plan ?? "pro"))\"}}"
        let token = [base64URL("{\"alg\":\"none\"}"), base64URL(claims), "not-a-signature"]
            .joined(separator: ".")
        return "{\"auth_mode\":\"chatgpt\",\"tokens\":{\"id_token\":\"\(token)\"}}"
    }

    private func base64URL(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
