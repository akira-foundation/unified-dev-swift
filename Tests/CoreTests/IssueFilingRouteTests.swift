import Foundation
import Testing
@testable import Core

@Suite("Which way a report reaches GitHub")
struct IssueFilingRouteTests {
    private func filed(_ attachments: IssueAttachments) -> IssueFilingOutcome {
        .filed(
            FiledIssue(
                number: 412,
                url: URL(string: "https://github.com/akira-foundation/unified-dev-swift/issues/412")!,
                attachments: attachments
            )
        )
    }

    @Test("gh that is ready files the issue itself")
    func readyUsesGh() {
        #expect(IssueFilingRoute.route(for: .ready) == .gh)
    }

    @Test("gh that is missing or signed out sends the owner to the page", arguments: [
        GitHubAccess.notInstalled, .signedOut,
    ])
    func otherwiseThePage(access: GitHubAccess) {
        #expect(IssueFilingRoute.route(for: access) == .page)
    }

    @Test("a filed issue is named by its number and its repository")
    func aFiledIssueIsNamed() {
        let sentence = IssueFilingRoute.sentence(for: filed(.none))

        #expect(sentence == "Issue #412 is open on akira-foundation/unified-dev-swift.")
    }

    @Test("pictures that went with the issue are not asked for again")
    func attachedPicturesAskForNothing() {
        let sentence = IssueFilingRoute.sentence(for: filed(.attached(2)))

        #expect(sentence.contains("2 screenshots went with it"))
        #expect(!sentence.lowercased().contains("finder"))
        #expect(!sentence.lowercased().contains("drag"))
        #expect(IssueFilingRoute.sentence(for: filed(.attached(1))).contains("1 screenshot went with it"))
    }

    @Test("pictures that did not upload are asked for, in the Finder, by dragging")
    func picturesThatDidNotGoAreAskedFor() {
        let sentence = IssueFilingRoute.sentence(for: filed(.notAttached(2)))

        #expect(sentence.contains("Issue #412 is open"))
        #expect(sentence.contains("2 screenshots could not be uploaded"))
        #expect(sentence.contains("with them waiting in the Finder window"))
        #expect(sentence.contains("dragged in"))
    }

    @Test("one picture that did not upload is spoken of in the singular")
    func onePictureReadsAsOne() {
        let sentence = IssueFilingRoute.sentence(for: filed(.notAttached(1)))

        #expect(sentence.contains("1 screenshot could not be uploaded"))
        #expect(sentence.contains("with it waiting in the Finder window"))
    }

    @Test("the page route says why it was taken, so a missing gh is not read as a failure")
    func thePageSaysWhy() {
        let noGh = IssueFilingRoute.sentence(for: .page(images: 0, reason: .noGh))
        let refused = IssueFilingRoute.sentence(
            for: .page(images: 0, reason: .ghRefused("Not Found (HTTP 404)"))
        )

        #expect(noGh.contains("gh is not signed in here"))
        #expect(noGh.contains("already in it"))
        #expect(refused.contains("Not Found (HTTP 404)"))
        #expect(refused.contains("already in it"))
        #expect(!refused.contains("not signed in"))
    }

    @Test("with pictures, the page route says where they are and what to do with them")
    func thePageExplainsPictures() {
        let many = IssueFilingRoute.sentence(for: .page(images: 2, reason: .noGh))
        let one = IssueFilingRoute.sentence(for: .page(images: 1, reason: .noGh))

        #expect(many.contains("2 screenshots are in the Finder window"))
        #expect(many.contains("dragged in before you submit"))
        #expect(one.contains("1 screenshot is in the Finder window"))
    }

    @Test("with no pictures neither way mentions them")
    func withoutPicturesNothingIsSaid() {
        for outcome in [filed(.none), .page(images: 0, reason: .noGh)] {
            let sentence = IssueFilingRoute.sentence(for: outcome).lowercased()

            #expect(!sentence.contains("drag"))
            #expect(!sentence.contains("screenshot"))
            #expect(!sentence.contains("finder"))
        }
    }

    @Test("only a filed issue carries a link to open")
    func onlyAFiledIssueHasALink() {
        #expect(IssueFilingRoute.link(for: filed(.none))?.absoluteString.hasSuffix("/issues/412") == true)
        #expect(IssueFilingRoute.link(for: .page(images: 0, reason: .noGh)) == nil)
    }
}
