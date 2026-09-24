import Foundation

#if DEBUG
@MainActor
enum ReviewFoldReport {
    private(set) static var collapsed: Set<String> = []

    static func report(collapsed paths: Set<String>) {
        collapsed = paths
    }
}
#endif
