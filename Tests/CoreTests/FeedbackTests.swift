import Foundation
import Testing
@testable import Core

@Suite("Feedback")
struct FeedbackTests {

    private func named(_ environment: Feedback.Environment) -> [String: Feedback.FieldValue] {
        Dictionary(uniqueKeysWithValues: environment.fields.map { ($0.name, $0.value) })
    }

    @Test("the environment says exactly thirteen things and no fourteenth")
    func environmentKeys() {
        let fields = named(FeedbackFixture.environment())

        #expect(Set(fields.keys) == [
            "app_version",
            "app_build",
            "macos_version",
            "architecture",
            "translated",
            "install_source",
            "agent",
            "agent_version",
            "available_agents",
            "permission_mode",
            "theme",
            "display_scale",
            "locale",
        ])
    }

    @Test("the environment reads back the facts it was handed")
    func environmentValues() {
        let fields = named(FeedbackFixture.environment())

        #expect(fields["app_version"] == .text("0.4.0"))
        #expect(fields["app_build"] == .text("412"))
        #expect(fields["macos_version"] == .text("26.1.0"))
        #expect(fields["architecture"] == .text("arm64"))
        #expect(fields["translated"] == .boolean(false))
        #expect(fields["install_source"] == .text("release"))
        #expect(fields["agent"] == .text("claude"))
        #expect(fields["agent_version"] == .text("2.1.234"))
        #expect(fields["available_agents"] == .list(["claude", "codex"]))
        #expect(fields["permission_mode"] == .text("accept-edits"))
        #expect(fields["theme"] == .text("dark"))
        #expect(fields["display_scale"] == .number(2))
        #expect(fields["locale"] == .text("nl-BE"))
    }

    @Test("a fact Unified Dev could not establish is left out, never guessed")
    func unknownFactsAreDropped() {
        let fields = named(
            FeedbackFixture.environment(
                appVersion: "", appBuild: "", macOSVersion: "", architecture: .unknown,
                translated: true,
                agent: "", agentVersion: "", availableAgents: [], permissionMode: "", locale: ""
            )
        )

        #expect(Set(fields.keys) == ["install_source", "theme", "display_scale"])
    }

    @Test("a display scale no screen has is brought inside the range the endpoint takes")
    func displayScaleIsClamped() {
        #expect(FeedbackFixture.environment(displayScale: 0).displayScale == 1)
        #expect(FeedbackFixture.environment(displayScale: 99).displayScale == 4)
    }

    private static let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])

    private func image(
        _ data: Data = FeedbackFixture.pngBytes, declaring type: String = "image/png"
    ) -> Feedback.Image {
        Feedback.Image(contentType: type, data: data)
    }

    @Test("the name that travels is Unified Dev's, and it matches what the bytes are")
    func imageNamesAreDerived() {
        #expect(image().filename == "attachment.png")
        #expect(image(FeedbackTests.jpegBytes).filename == "attachment.jpg")
    }

    @Test("bytes beat the name they arrived under")
    func bytesDecideTheType() {
        let renamed = image(FeedbackTests.jpegBytes, declaring: "image/png")

        #expect(renamed.contentType == "image/jpeg")
        #expect(renamed.filename == "attachment.jpg")
    }

    @Test("what a run of bytes is, read from the bytes", arguments: [
        (Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), "image/png"),
        (Data([0xFF, 0xD8, 0xFF, 0xE0]), "image/jpeg"),
        (Data("GIF89a....".utf8), "image/gif"),
        (Data("RIFF????WEBPVP8 ".utf8), "image/webp"),
        (Data("????ftypheic".utf8), "image/heic"),
        (Data("????ftypmif1".utf8), "image/heif"),
    ])
    func sniffing(bytes: Data, type: String) {
        #expect(Feedback.sniffedContentType(bytes) == type)
    }

    @Test("something that is not a picture is not recognised as one")
    func sniffingRefusesTheRest() {
        #expect(Feedback.sniffedContentType(Data("%PDF-1.7".utf8)) == nil)
        #expect(Feedback.sniffedContentType(Data("<svg xmlns=".utf8)) == nil)
        #expect(Feedback.sniffedContentType(Data()) == nil)
    }

    @Test("every type Unified Dev sends has an extension the endpoint's list names")
    func everyTypeHasAnExtension() {
        let accepted = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]

        for type in Feedback.imageContentTypes {
            #expect(accepted.contains(Feedback.fileExtension(for: type)))
        }
    }

    @Test("a very long message is cut rather than refused")
    func messageCap() {
        let long = Feedback.trimmed(
            String(repeating: "a", count: Feedback.maxMessageCharacters + 500),
            to: Feedback.maxMessageCharacters
        )

        #expect(long.count == Feedback.maxMessageCharacters)
    }

    @Test("the sheet warns before the limit and says what will be lost past it")
    func remainingCounter() {
        #expect(Feedback.remainingMessage(count: 100, limit: 5_000) == nil)
        #expect(Feedback.remainingMessage(count: 4_900, limit: 5_000) == "100 characters left")
        #expect(Feedback.remainingMessage(count: 5_200, limit: 5_000)?.contains("first 5000") == true)
    }

    @Test("the three limits are the endpoint's, and each is said in its own words")
    func limits() {
        #expect(Feedback.maxImages == 5)
        #expect(Feedback.maxImageBytes == 8 * 1024 * 1024)
        #expect(Feedback.maxTotalImageBytes == 12 * 1024 * 1024)

        let tooLarge = Feedback.tooLargeMessage(name: "shot.png", bytes: 9 * 1024 * 1024)
        #expect(tooLarge.contains("shot.png"))
        #expect(tooLarge.contains("8 MB"))
        #expect(Feedback.tooManyMessage().contains("5"))
        #expect(Feedback.tooMuchMessage().contains("12 MB"))
        #expect(Set([tooLarge, Feedback.tooManyMessage(), Feedback.tooMuchMessage()]).count == 3)
    }

    @Test("a report with no words in it cannot be sent")
    func emptyMessageCannotSend() {
        #expect(!Feedback.canSend(message: "   \n "))
        #expect(Feedback.canSend(message: "it broke"))
    }

    @Test("a build knows whether it is a release, somebody's own, or somebody's own with edits in it")
    func installSources() {
        #expect(Feedback.InstallSource(buildChannel: "release", masterCommit: nil) == .release)
        #expect(Feedback.InstallSource(buildChannel: "release", masterCommit: "abc1234") == .local)
        #expect(Feedback.InstallSource(buildChannel: nil, masterCommit: nil) == .local)

        #expect(Feedback.InstallSource(buildChannel: nil, masterCommit: "abc1234-dirty") == .localDirty)
        #expect(Feedback.InstallSource(buildChannel: nil, masterCommit: nil, isDirty: true) == .localDirty)
        #expect(Feedback.InstallSource(buildChannel: "release", masterCommit: nil, isDirty: true) == .release)

        for source in Feedback.InstallSource.allCases {
            #expect(SystemReadings.matches(source.rawValue, Feedback.slugPattern))
        }
    }

    @Test("a translated process reports the slice it is running as, and says it was translated")
    func architectures() {
        #expect(Feedback.Architecture(isARM: true, isTranslated: false).wireName == "arm64")
        #expect(Feedback.Architecture(isARM: false, isTranslated: false).wireName == "x86_64")
        #expect(Feedback.Architecture(isARM: true, isTranslated: true).wireName == "x86_64")
        #expect(Feedback.Architecture.unknown.wireName == nil)

        #expect(FeedbackFixture.environment(architecture: .x86_64, translated: false).translated == false)
        #expect(FeedbackFixture.environment(architecture: .x86_64, translated: true).translated == true)
        #expect(FeedbackFixture.environment(architecture: .unknown, translated: true).translated == nil)
    }

    @Test("every permission mode has a slug the endpoint accepts")
    func permissionModeWireNames() {
        for mode in PermissionMode.allCases {
            #expect(SystemReadings.matches(Feedback.wireName(mode), Feedback.slugPattern))
        }
    }

    @Test("every agent slug the ping uses is a slug this endpoint takes too")
    func agentWireNames() {
        for kind in AgentKind.allCases {
            #expect(SystemReadings.matches(SystemReadings.wireName(kind), Feedback.slugPattern))
        }
    }

    @Test("the thank you says nothing about a reference")
    func thanksIsPlain() {
        #expect(!Feedback.Copy.reportSent.contains("Reference"))
        #expect(!Feedback.Copy.reportSentDetail.contains("Reference"))
        #expect(!Feedback.Copy.promptSentDetail.contains("Reference"))
    }

    @Test("the logs checkbox says what it sends, and the sheet says how to reach a person")
    func copyDescribesWhatIsSent() {
        #expect(Feedback.Copy.logsDetail.contains("half hour"))
        #expect(Feedback.Copy.logsDetail.contains("credential"))
        #expect(Feedback.Copy.logsDetail.contains("branch names"))
        #expect(Feedback.Copy.reportBlurb.contains(Feedback.supportEmail))
        #expect(Feedback.Copy.environmentNote.contains("No file"))
    }

    @Test("the sheet says it publishes, and where, before anybody presses send")
    func theSheetSaysItIsPublic() {
        #expect(Feedback.Copy.environmentNote.contains("public issue"))
        #expect(Feedback.Copy.environmentNote.contains(AppRepository.slug))
        #expect(Feedback.Copy.environmentNote.contains("recent logs"))
    }
}
