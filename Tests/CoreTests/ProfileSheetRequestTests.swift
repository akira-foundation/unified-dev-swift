import Foundation
import Testing
@testable import Core

@Suite("Asking for the profile sheet")
struct ProfileSheetRequestTests {
    private let akira = Profile(
        id: ProfileID("akira"), name: "Akira", folder: "akira", colour: "4C8DF6", symbol: "building.2"
    )
    private let debtges = Profile(
        id: ProfileID("debtges"), name: "Debtges", folder: "debtges", colour: "E06C2A", symbol: "briefcase"
    )

    @Test("with no sheet open, the sheet asked for is the one shown")
    func nothingOpen() {
        #expect(ProfileSheetRequest.presenting(.edit(debtges), over: nil) == .edit(debtges))
        #expect(ProfileSheetRequest.presenting(.new, over: nil) == .new)
    }

    @Test("a sheet already editing one profile is not handed another")
    func editingStaysOnItsProfile() {
        #expect(ProfileSheetRequest.presenting(.edit(debtges), over: .edit(akira)) == .edit(akira))
    }

    @Test("a sheet already editing a profile does not turn into a new one")
    func editingDoesNotBecomeNew() {
        #expect(ProfileSheetRequest.presenting(.new, over: .edit(akira)) == .edit(akira))
    }

    @Test("a new profile half filled in does not turn into the settings of another")
    func newDoesNotBecomeEditing() {
        #expect(ProfileSheetRequest.presenting(.edit(akira), over: .new) == .new)
    }

    @Test("each request is told apart by the profile it edits")
    func identity() {
        #expect(ProfileSheetRequest.edit(akira).id != ProfileSheetRequest.edit(debtges).id)
        #expect(ProfileSheetRequest.new.id != ProfileSheetRequest.edit(akira).id)
    }
}
