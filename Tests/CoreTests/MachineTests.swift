import Testing
@testable import Core

@Suite("Machine")
struct MachineTests {
    @Test("a lid is found from the hardware, and only then from the name")
    func portables() {
        #expect(Machine.isPortable(model: "Mac16,6", hasInternalBattery: true, publishesClamshellState: false))
        #expect(Machine.isPortable(model: "Mac16,6", hasInternalBattery: false, publishesClamshellState: true))
        #expect(Machine.isPortable(model: "MacBookPro18,3", hasInternalBattery: false, publishesClamshellState: false))
        #expect(!Machine.isPortable(model: "Mac16,6", hasInternalBattery: false, publishesClamshellState: false))
        #expect(!Machine.isPortable(model: "Macmini9,1", hasInternalBattery: false, publishesClamshellState: false))
        #expect(!Machine.isPortable(model: "", hasInternalBattery: false, publishesClamshellState: false))
    }
}
