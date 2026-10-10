import Foundation

public struct FiledIssue: Sendable, Equatable {
    public let number: Int
    public let url: URL
    public let attachments: IssueAttachments

    public init(number: Int, url: URL, attachments: IssueAttachments) {
        self.number = number
        self.url = url
        self.attachments = attachments
    }
}

public enum IssueAttachments: Sendable, Equatable {
    case none
    case attached(Int)
    case partly(Int)
    case notAttached(Int)
}

public enum IssueFailure: Error, Sendable, Equatable {
    case refused(String)
    case unanswered(String)

    public var message: String {
        switch self {
        case .refused(let said), .unanswered(let said): said
        }
    }
}

extension GitHub {
    public static func createIssue(
        slug: String,
        title: String,
        body: String,
        labels: [String],
        images: [String] = []
    ) async -> Result<FiledIssue, IssueFailure> {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("issue-\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            try body.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            return .failure(.refused("Unified Dev could not write the report to a file to send."))
        }

        let outcome = await filed(
            slug: slug, title: title, bodyFile: file.path, labels: labels, images: images
        )
        guard case .failure(.refused(let said)) = outcome, !images.isEmpty, cannotAttach(said) else {
            return outcome
        }

        return await filed(
            slug: slug, title: title, bodyFile: file.path, labels: labels, images: []
        ).map {
            FiledIssue(number: $0.number, url: $0.url, attachments: .notAttached(images.count))
        }
    }

    private static func filed(
        slug: String, title: String, bodyFile: String, labels: [String], images: [String]
    ) async -> Result<FiledIssue, IssueFailure> {
        var arguments = ["issue", "create", "--repo", slug, "--title", title, "--body-file", bodyFile]
        for label in labels { arguments += ["--label", label] }
        for image in images { arguments += ["--attach", image] }

        guard let result = try? await run("gh", arguments, timeout: .seconds(180)) else {
            return .failure(
                .unanswered(
                    "gh did not answer in time. Check \(slug) before sending again, in case the "
                        + "issue was opened after all."
                )
            )
        }

        let said = result.stderr.isEmpty ? result.stdout : result.stderr
        guard let filed = issue(in: result.stdout, of: slug) else {
            return .failure(.refused(said.isEmpty ? "gh said nothing at all." : said))
        }

        return .success(
            FiledIssue(
                number: filed.number,
                url: filed.url,
                attachments: attachments(of: images.count, uploaded: result.ok)
            )
        )
    }

    private static func attachments(of count: Int, uploaded: Bool) -> IssueAttachments {
        guard count > 0 else { return .none }
        return uploaded ? .attached(count) : .partly(count)
    }

    static func issue(in output: String, of slug: String) -> (number: Int, url: URL)? {
        for line in output.components(separatedBy: .newlines).reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed), url.scheme == "https",
                  url.pathComponents.dropLast().last == "issues",
                  url.path.hasPrefix("/\(slug)/"),
                  let number = Int(url.lastPathComponent), number > 0
            else { continue }
            return (number, url)
        }
        return nil
    }

    static func cannotAttach(_ said: String) -> Bool {
        let lowered = said.lowercased()
        guard lowered.contains("attach") else { return false }
        return lowered.contains("unknown flag") || lowered.contains("unknown shorthand")
    }
}
