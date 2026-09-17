import Foundation
import Core

@MainActor
struct BrowserPaneHost {
    var openTab: (URL) -> Void = { _ in }
    var report: (BrowserPopups.Notice) -> Void = { _ in }
}
