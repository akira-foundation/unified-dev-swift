import Foundation

public enum CanvasQuitFlush {
    public static let limit: Duration = .seconds(3)

    @MainActor
    public static func run(within limit: Duration = limit, _ work: @escaping @MainActor () async -> Void) async {
        let (finished, signal) = AsyncStream.makeStream(of: Void.self)
        Task { @MainActor in
            await work()
            signal.yield()
        }
        Task {
            try? await Task.sleep(for: limit)
            signal.yield()
        }
        for await _ in finished { break }
        signal.finish()
    }
}
