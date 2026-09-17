import Testing
@testable import Core

@Suite("Release version")
struct ReleaseVersionTests {
    private func version(_ text: String) throws -> ReleaseVersion {
        try #require(ReleaseVersion(text))
    }

    @Test("A tag and the bundle's version string read as the same version")
    func leadingVIsOptional() throws {
        #expect(try version("v1.4.0") == version("1.4.0"))
        #expect(try version("v1.4.0").description == "1.4.0")
    }

    @Test("Components compare as numbers, not as text")
    func numericComparison() throws {
        #expect(try version("1.10.0") > version("1.9.0"))
        #expect(try version("2.0.0") > version("1.99.99"))
        #expect(try version("1.4.1") > version("1.4.0"))
    }

    @Test("A missing trailing component counts as zero")
    func paddedComponents() throws {
        #expect(try version("1.4") == version("1.4.0"))
        #expect(try version("1.4.0.1") > version("1.4"))
    }

    @Test("A prerelease comes before the release it leads to")
    func prereleaseOrdering() throws {
        #expect(try version("1.4.0-beta.1") < version("1.4.0"))
        #expect(try version("1.4.0-beta.2") < version("1.4.0-beta.10"))
        #expect(try version("1.4.0-beta.1").isPrerelease)
        #expect(try version("1.4.0").isPrerelease == false)
    }

    @Test("Text that is not a version is refused", arguments: ["", "v", "banana", "1..2", "1.2.3.4.5", "1.2-", "1.x.0"])
    func refusesNonVersions(_ text: String) {
        #expect(ReleaseVersion(text) == nil)
    }
}
