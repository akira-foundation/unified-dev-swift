import Foundation

@MainActor
enum TranscriptDrawn {
    private(set) static var rows = 0

    static func note(_ count: Int) { rows = count }
}
