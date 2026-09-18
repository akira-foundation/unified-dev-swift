import Foundation

public enum LaunchOverride {
    public static func value(
        _ name: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        info: [String: Any]? = Bundle.main.infoDictionary
    ) -> String? {
        if let value = info?[name] as? String, !value.isEmpty { return value }
        if let value = environment[name], !value.isEmpty { return value }
        return nil
    }
}
