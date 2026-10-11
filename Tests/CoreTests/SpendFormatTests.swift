import Testing
import Foundation
@testable import Core

@Suite("Spend format")
struct SpendFormatTests {
    @Test("tokens are read at the scale they are counted in")
    func tokenScale() {
        #expect(SpendFormat.tokens(412) == "412")
        #expect(SpendFormat.tokens(9_540_000).hasSuffix("M"))
        #expect(SpendFormat.tokens(3_555_000_000).hasSuffix("B"))
    }

    @Test("a count that rounds up to the next unit is named in that unit")
    func unitRollover() {
        #expect(SpendFormat.tokens(999_999).hasSuffix("M"))
        #expect(SpendFormat.tokens(999_999_999).hasSuffix("B"))
        #expect(SpendFormat.tokens(999) == "999")
        #expect(SpendFormat.tokens(1_000).hasSuffix("K"))
    }

    @Test("a cost too small to show as cents says so rather than reading as nothing")
    func smallMoney() {
        #expect(SpendFormat.money(0.004) == "<$0.01")
        #expect(SpendFormat.money(0) != "<$0.01")
    }

    @Test("a share under a tenth of a percent says so rather than rounding to nothing")
    func smallShare() {
        #expect(SpendFormat.share(0.0003).hasPrefix("<"))
        #expect(!SpendFormat.share(0.003).hasPrefix("<"))
        #expect(SpendFormat.share(0.003).hasSuffix("%"))
    }

    @Test("the price line names the day the table was measured on, in the zone it was measured in")
    func pricedLine() {
        let line = SpendFormat.pricedOn(ModelPrices.measuredOn)
        #expect(line.contains("2026"))
        #expect(line.contains("11"))
        #expect(!line.contains("10 "))
    }
}
