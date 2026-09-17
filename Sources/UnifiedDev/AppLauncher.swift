import Foundation

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
