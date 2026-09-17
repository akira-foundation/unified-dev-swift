import Foundation
import Testing
@testable import Core

@Suite("Feedback: the sender")
struct FeedbackSenderTests {
    private static let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01])

    private func environment() -> Feedback.Environment {
        Feedback.Environment(
            appVersion: "0.3.0",
            appBuild: "452",
            macOSVersion: "26.0",
            architecture: .arm64,
            translated: false,
            installSource: Feedback.InstallSource(buildChannel: "release", masterCommit: nil, isDirty: nil),
            agent: "claude_code",
            agentVersion: "1.0.0",
            availableAgents: ["claude"],
            permissionMode: "accept-edits",
            theme: .dark,
            displayScale: 2,
            locale: "en-GB"
        )
    }

    private func report(email: String?) -> Feedback.Report {
        Feedback.Report(
            message: "the sidebar flickers",
            email: email,
            logs: "a line of log",
            images: [Feedback.Image(contentType: "image/png", data: Self.pngBytes)],
            token: "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            environment: environment()
        )
    }

    private func text(of body: Feedback.Body) -> String {
        String(decoding: body.data, as: UTF8.self)
    }

    @Test("a report with pictures still carries the address it was given")
    func multipartReportKeepsTheAddress() throws {
        let body = try Feedback.body(for: report(email: "freek@akira-io.com"), boundary: "B")

        #expect(body.contentType == "multipart/form-data; boundary=B")
        #expect(text(of: body).contains("name=\"email\"\r\n\r\nfreek@akira-io.com\r\n"))
    }

    @Test("every field the JSON body has is a part of the multipart body too")
    func multipartAndJSONCarryTheSameFields() throws {
        let sent = report(email: "freek@akira-io.com")
        let written = text(of: try Feedback.body(for: sent, boundary: "B"))
        let json = try #require(
            try JSONSerialization.jsonObject(with: try Feedback.json(sent)) as? [String: Any]
        )

        #expect(json.keys.sorted() == ["email", "environment", "logs", "message", "token"])
        for key in json.keys where key != "environment" {
            #expect(written.contains("name=\"\(key)\"\r\n\r\n"))
        }
    }

    @Test("a report with pictures and no address has no address part at all")
    func multipartReportWithoutAddress() throws {
        let written = text(of: try Feedback.body(for: report(email: nil), boundary: "B"))

        #expect(!written.contains("name=\"email\""))
    }
}
