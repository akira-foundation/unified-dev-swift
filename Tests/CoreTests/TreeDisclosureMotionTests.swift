import Testing
@testable import Core

@Suite struct TreeDisclosureMotionTests {
    @Test func aFolderOfAFewFilesMakesRoomForThem() {
        #expect(TreeDisclosureMotion.rows(changing: 6, reduceMotion: false)
            == .animated(seconds: TranscriptMotion.disclosure(reduceMotion: false) ?? 0))
    }

    @Test func aFolderTooBigToWatchArrivesInstead() {
        let limit = TreeDisclosureMotion.rowLimit
        #expect(TreeDisclosureMotion.rows(changing: limit, reduceMotion: false) != .instant)
        #expect(TreeDisclosureMotion.rows(changing: limit + 1, reduceMotion: false) == .instant)
    }

    @Test func anEmptyDirectoryHasNothingToTime() {
        #expect(TreeDisclosureMotion.rows(changing: 0, reduceMotion: false) == .instant)
        #expect(TreeDisclosureMotion.instant.seconds == nil)
    }

    @Test func theChevronTurnsWhateverTheFolderHolds() {
        #expect(TreeDisclosureMotion.chevron(reduceMotion: false).seconds != nil)
        #expect(TreeDisclosureMotion.rows(changing: 5_000, reduceMotion: false) == .instant)
    }

    @Test func reduceMotionDropsBothHalvesRatherThanSlowingThem() {
        #expect(TreeDisclosureMotion.rows(changing: 6, reduceMotion: true) == .instant)
        #expect(TreeDisclosureMotion.chevron(reduceMotion: true) == .instant)
    }

    @Test func itTakesTheSameLengthAsARowUnfoldingInTheTranscript() {
        #expect(TreeDisclosureMotion.chevron(reduceMotion: false).seconds
            == TranscriptMotion.disclosure(reduceMotion: false))
    }
}
