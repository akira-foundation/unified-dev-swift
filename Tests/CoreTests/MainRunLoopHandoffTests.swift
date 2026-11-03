import Dispatch
import Foundation
import Testing
@testable import Core

@MainActor
private final class MainQueueDrain {
    var drained = false
}

@MainActor
private final class WorkRecord {
    var ran = false
}

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct MainRunLoopHandoffTests {
    @Test func aNestedRunLoopInsideTheWorkCanStillDrainTheMainQueue() async {
        let drain = MainQueueDrain()
        await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
            MainRunLoopHandoff.perform {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { drain.drained = true }
                }
                let keepsTheLoopOpen = Timer(timeInterval: 60, repeats: false) { _ in }
                RunLoop.current.add(keepsTheLoopOpen, forMode: .default)
                CFRunLoopRunInMode(.defaultMode, 0.5, false)
                keepsTheLoopOpen.invalidate()
                finished.resume()
            }
        }
        #expect(drain.drained)
    }

    @Test func theWorkRunsInACommonModeOtherThanTheDefault() {
        let modeName = "MainRunLoopHandoffTests.modal" as CFString
        let mode = CFRunLoopMode(modeName)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), mode)
        let record = WorkRecord()

        MainRunLoopHandoff.perform { record.ran = true }
        let keepsTheLoopOpen = Timer(timeInterval: 60, repeats: false) { _ in }
        RunLoop.main.add(keepsTheLoopOpen, forMode: RunLoop.Mode(modeName as String))
        CFRunLoopRunInMode(mode, 0.5, false)
        keepsTheLoopOpen.invalidate()

        #expect(record.ran)
    }
}
