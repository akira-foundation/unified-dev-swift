import Foundation

public struct BrowserToolbar: Equatable, Sendable {
    public struct Control: Equatable, Sendable {
        public var symbol: String
        public var name: String
        public var help: String
        public var isEnabled: Bool
        public var isActive: Bool

        public init(symbol: String, name: String, help: String, isEnabled: Bool, isActive: Bool = false) {
            self.symbol = symbol
            self.name = name
            self.help = help
            self.isEnabled = isEnabled
            self.isActive = isActive
        }
    }

    public var page: BrowserTabTitle.BrowserPage
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var isLoading: Bool
    public var loadProgress: Double
    public var isCapturing: Bool

    public init(
        page: BrowserTabTitle.BrowserPage = BrowserTabTitle.BrowserPage(),
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isLoading: Bool = false,
        loadProgress: Double = 0,
        isCapturing: Bool = false
    ) {
        self.page = page
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
        self.loadProgress = loadProgress
        self.isCapturing = isCapturing
    }

    public var progress: Double? {
        guard isLoading, loadProgress > 0, loadProgress < 1 else { return nil }
        return loadProgress
    }

    public var destination: URL? {
        BrowserAddress.url(from: page.address)
    }

    public var back: Control {
        Control(
            symbol: "chevron.backward",
            name: "Back",
            help: "Show the previous page",
            isEnabled: canGoBack
        )
    }

    public var forward: Control {
        Control(
            symbol: "chevron.forward",
            name: "Forward",
            help: "Show the next page",
            isEnabled: canGoForward
        )
    }

    public var reload: Control {
        if isLoading {
            return Control(
                symbol: "xmark",
                name: "Stop",
                help: "Stop loading this page",
                isEnabled: true
            )
        }
        return Control(
            symbol: "arrow.clockwise",
            name: "Reload",
            help: "Reload this page",
            isEnabled: destination != nil
        )
    }

    public var screenshot: Control {
        Control(
            symbol: "camera",
            name: "Send a Screenshot to the Agent",
            help: "Send a screenshot of this page to the agent",
            isEnabled: destination != nil && !isCapturing
        )
    }

    public var share: Control {
        Control(
            symbol: "square.and.arrow.up",
            name: "Share",
            help: "Share this page",
            isEnabled: shareable != nil
        )
    }

    public var regionCapture: Control {
        Control(
            symbol: "crop",
            name: "Comment on an Area",
            help: "Select part of this page and add a comment to the draft",
            isEnabled: destination != nil && !isCapturing
        )
    }

    public struct Shareable: Equatable, Sendable {
        public var url: URL
        public var name: String

        public init(url: URL, name: String) {
            self.url = url
            self.name = name
        }
    }

    public var shareable: Shareable? {
        guard let url = destination else { return nil }
        return Shareable(
            url: url,
            name: BrowserTabTitle.title(
                page: page.title, address: page.address, fallback: url.absoluteString
            )
        )
    }

    public static let historyLimit = 10

    public struct HistoryEntry: Equatable, Sendable, Identifiable {
        public var id: Int
        public var name: String

        public init(id: Int, name: String) {
            self.id = id
            self.name = name
        }
    }

    public static func backMenu(_ pages: [BrowserTabTitle.BrowserPage]) -> [HistoryEntry] {
        entries(Array(pages.reversed()), distance: { -($0 + 1) })
    }

    public static func forwardMenu(_ pages: [BrowserTabTitle.BrowserPage]) -> [HistoryEntry] {
        entries(pages, distance: { $0 + 1 })
    }

    private static func entries(
        _ pages: [BrowserTabTitle.BrowserPage], distance: (Int) -> Int
    ) -> [HistoryEntry] {
        pages
            .prefix(historyLimit)
            .enumerated()
            .map { offset, page in
                HistoryEntry(
                    id: distance(offset),
                    name: BrowserTabTitle.title(
                        page: page.title, address: page.address, fallback: page.address
                    )
                )
            }
            .filter { !$0.name.isEmpty }
    }
}
