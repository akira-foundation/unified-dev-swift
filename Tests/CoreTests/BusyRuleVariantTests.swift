import Testing
@testable import Core

@Suite("Which figure the activity rule draws")
struct BusyRuleVariantTests {
    @Test("the one the window draws is one of the ones the gallery draws")
    func liveIsInTheSet() {
        #expect(BusyRuleVariant.allCases.contains(BusyRuleVariant.live))
        #expect(BusyRuleVariant.allCases.count == 3)
    }

    @Test("every variant names itself and says what it does")
    func everyVariantIsDescribed() {
        for variant in BusyRuleVariant.allCases {
            #expect(!variant.title.isEmpty)
            #expect(!variant.note.isEmpty)
        }
        #expect(Set(BusyRuleVariant.allCases.map(\.title)).count == BusyRuleVariant.allCases.count)
    }

    @Test("the swell is the only one that stays where it is")
    func onlyTheSwellStaysPut() {
        #expect(BusyRuleVariant.swell.travels == false)
        #expect(BusyRuleVariant.crest.travels)
        #expect(BusyRuleVariant.current.travels)
        #expect(BusyRuleVariant.live.travels, "the report was that a still line says nothing")
    }
}
