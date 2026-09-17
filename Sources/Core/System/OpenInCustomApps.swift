import Foundation

public struct OpenInCustomApps: @unchecked Sendable {
    public static let key = "openIn.customApps"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private struct Stored: Codable {
        let bundleID: String
        let name: String
        let targets: Int
        let fileName: String

        init(_ app: ExternalApp) {
            bundleID = app.bundleID
            name = app.name
            targets = app.targets.rawValue
            fileName = app.fileName
        }

        var app: ExternalApp {
            ExternalApp(
                bundleID: bundleID, name: name, targets: OpenTargets(rawValue: targets), fileName: fileName
            )
        }
    }

    public var apps: [ExternalApp] {
        get {
            guard let data = defaults.data(forKey: Self.key) else { return [] }
            return ((try? JSONDecoder().decode([Stored].self, from: data)) ?? []).map(\.app)
        }
        nonmutating set {
            guard !newValue.isEmpty else {
                defaults.removeObject(forKey: Self.key)
                return
            }
            guard let data = try? JSONEncoder().encode(newValue.map(Stored.init)) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }

    public enum Refusal: Equatable, Sendable {
        case alreadyInCatalogue(name: String)
        case alreadyAdded
    }

    @discardableResult
    public func add(_ app: ExternalApp) -> Refusal? {
        if let owner = EditorCatalog.owner(ofBundleID: app.bundleID) {
            return .alreadyInCatalogue(name: owner.name)
        }
        var current = apps
        if current.contains(where: { $0.bundleID.caseInsensitiveCompare(app.bundleID) == .orderedSame }) {
            return .alreadyAdded
        }
        current.append(app)
        apps = current
        return nil
    }

    public func remove(bundleID: String) {
        apps = apps.filter { $0.bundleID.caseInsensitiveCompare(bundleID) != .orderedSame }
    }

    public func setTargets(_ targets: OpenTargets, forBundleID bundleID: String) {
        apps = apps.map { app in
            guard app.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame else { return app }
            return ExternalApp(bundleID: app.bundleID, name: app.name, targets: targets, fileName: app.fileName)
        }
    }
}
