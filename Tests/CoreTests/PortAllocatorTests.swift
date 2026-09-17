import Testing
import Foundation
@testable import Core

@Suite("PortAllocator", .serialized)
struct PortAllocatorTests {
    @Test("hands out a block at or after the requested start")
    func allocatesFromTheStart() throws {
        let first = try PortAllocator.allocate(taken: [], start: 41_000)
        #expect(first >= 41_000)
        #expect(first.isMultiple(of: PortAllocator.blockSize))
    }

    @Test("never hands the same block out twice")
    func doesNotRepeatABlock() throws {
        let base = 42_000
        let first = try PortAllocator.allocate(taken: [], start: base)
        let second = try PortAllocator.allocate(taken: [first], start: base)
        #expect(second > first)
        #expect((second - first).isMultiple(of: PortAllocator.blockSize))
    }

    @Test("one taken port disqualifies the whole block it sits in")
    func oneTakenPortSkipsTheBlock() throws {
        let base = 41_000
        let first = try PortAllocator.allocate(taken: [], start: base)
        let second = try PortAllocator.allocate(taken: [first + 3], start: base)
        #expect(second >= first + PortAllocator.blockSize)
        #expect((second - first).isMultiple(of: PortAllocator.blockSize))
    }

    @Test("fails loudly when the range cannot hold a block")
    func refusesARangeTooSmall() {
        #expect(throws: PortAllocatorError.self) {
            _ = try PortAllocator.allocate(taken: [], start: 3_100, limit: 3_105)
        }
    }

    @Test("fails loudly rather than returning a port that is taken")
    func refusesWhenEveryPortIsTaken() {
        #expect(throws: PortAllocatorError.self) {
            _ = try PortAllocator.allocate(taken: Set(3_100...3_200), start: 3_100, limit: 3_150)
        }
    }
}
