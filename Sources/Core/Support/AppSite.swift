import Foundation

/// The app's own address, printed and linked from the About window's plinth.
///
/// Data in the core, rendered by the view, for the same reason the rest of the About window's
/// content is: a sentence typed into a View is a sentence nothing can test.
public enum AppSite {
    public static let host = "unified-dev.akira-io.com"
    public static let url = URL(string: "https://unified-dev.akira-io.com")!
    public static let helpURL = url.appendingPathComponent("support")
}
