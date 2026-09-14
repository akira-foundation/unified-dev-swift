import Foundation

/// A debug probe must exit before SwiftUI constructs AppModel or opens a database.
/// Normal launches still enter through SwiftUI's App.main implementation.
@main
enum AppLauncher {
    @MainActor
    static func main() async {
        #if DEBUG
        if WelcomeLayoutProbe.isRequested { WelcomeLayoutProbe.runAndExit() }
        if ReviewRunProbe.isRequested { ReviewRunProbe.runAndExit() }
        #endif
        UnifiedDevApp.main()
    }
}
