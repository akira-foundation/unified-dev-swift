import Foundation

public enum BrowserPageOrigin {
    public static func name(scheme: String, host: String, port: Int) -> String? {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return nil }

        let scheme = scheme.lowercased()
        let isDefaultPort = (scheme == "https" && (port == 443 || port == 0))
            || (scheme == "http" && (port == 80 || port == 0))
        return isDefaultPort ? host : "\(host):\(port)"
    }

    public static func uploadMessage(from name: String?, allowsMultiple: Bool) -> String {
        let what = allowsMultiple ? "the files" : "the file"
        guard let name else { return "Choose \(what) you want to give this page." }
        return "Choose \(what) you want to give \(name)."
    }
}
