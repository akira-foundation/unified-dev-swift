import Foundation

public struct BrowserLoadFailure: Equatable, Sendable {
    public let title: String
    public let message: String
    public let namesTheAddress: Bool

    public init(title: String, message: String, namesTheAddress: Bool = true) {
        self.title = title
        self.message = message
        self.namesTheAddress = namesTheAddress
    }

    public static func of(domain: String, code: Int, host: String? = nil) -> BrowserLoadFailure? {
        if domain == NSURLErrorDomain, code == NSURLErrorCancelled { return nil }
        if domain == "WebKitErrorDomain", code == 102 || code == 101 { return nil }

        guard domain == NSURLErrorDomain else {
            return BrowserLoadFailure(
                title: "This page did not load",
                message: "Something went wrong loading this page. Try again, or open it in your browser."
            )
        }

        switch code {
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return BrowserLoadFailure(
                title: "Cannot find that address",
                message: named(host, "There is no server at %@.", "There is no server at that address.")
                    + " Check the spelling."
            )
        case NSURLErrorCannotConnectToHost:
            return BrowserLoadFailure(
                title: "Cannot connect",
                message: named(host, "%@ refused the connection.", "The server refused the connection.")
                    + " It may be down, or nothing may be listening on that port."
            )
        case NSURLErrorNotConnectedToInternet:
            return BrowserLoadFailure(
                title: "No internet connection",
                message: "This Mac is not online, so nothing can be fetched.",
                namesTheAddress: false
            )
        case NSURLErrorTimedOut:
            return BrowserLoadFailure(
                title: "The server took too long",
                message: named(host, "%@ did not answer in time.", "The server did not answer in time.")
                    + " It may be starting up."
            )
        case NSURLErrorUnsupportedURL, NSURLErrorBadURL:
            return BrowserLoadFailure(
                title: "That is not an address this pane can open",
                message: "Only http and https pages, and local files, open here."
            )
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid:
            return BrowserLoadFailure(
                title: "The connection is not private",
                message: named(host, "%@ presented a certificate this Mac does not trust.",
                               "The server presented a certificate this Mac does not trust.")
            )
        case NSURLErrorNetworkConnectionLost:
            return BrowserLoadFailure(
                title: "The connection dropped",
                message: "The connection was lost while the page was loading. Try again.",
                namesTheAddress: false
            )
        case NSURLErrorFileDoesNotExist, NSURLErrorFileIsDirectory:
            return BrowserLoadFailure(
                title: "That file is not there",
                message: "Nothing is at that path any more. It may have been moved or deleted."
            )
        default:
            return BrowserLoadFailure(
                title: "This page did not load",
                message: "Something went wrong loading this page. Try again, or open it in your browser."
            )
        }
    }

    private static func named(_ host: String?, _ withHost: String, _ without: String) -> String {
        guard let host, !host.isEmpty else { return without }
        return withHost.replacingOccurrences(of: "%@", with: host)
    }
}
