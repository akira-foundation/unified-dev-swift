import Foundation

public enum MainRunLoopHandoff {
    public static func perform(_ work: @escaping @MainActor @Sendable () -> Void) {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated(work)
        }
    }
}
