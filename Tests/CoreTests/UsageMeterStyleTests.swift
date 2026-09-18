import Testing
import Foundation
@testable import Core

@Suite("Usage meter style")
struct UsageMeterStyleTests {
    @Test("nothing stored counts what has been used")
    func nothingStored() {
        #expect(UsageMeterStyle(stored: nil) == .used)
        #expect(UsageDisplayOptions().meterStyle == .used)
    }

    @Test("an unreadable stored value falls back to used")
    func unreadable() {
        #expect(UsageMeterStyle(stored: "remaining") == .used)
    }

    @Test("a stored choice wins over the default", arguments: UsageMeterStyle.allCases)
    func storedChoice(style: UsageMeterStyle) {
        #expect(UsageMeterStyle(stored: style.rawValue) == style)
    }
}
