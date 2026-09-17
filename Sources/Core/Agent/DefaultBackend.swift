import Foundation

public struct DefaultBackend: Equatable, Sendable {
    public var kind: AgentKind
    public var model: String
    public var effort: String

    public init(kind: AgentKind, model: String, effort: String) {
        self.kind = kind
        self.model = model
        self.effort = effort
    }

    public static func resolve(
        model: String,
        effort: String,
        app: AppDefaults,
        running: AgentKind = .claudeCode,
        models: [AgentKind: [AgentModel]] = [:]
    ) -> DefaultBackend {
        let identity = ModelIdentifier.resolve(model, models: models)
        let kind: AgentKind
        if identity.namesBackend, let named = identity.kind {
            kind = named
        } else if model == app.model {
            kind = app.backend
        } else {
            kind = identity.kind ?? running
        }
        return DefaultBackend(
            kind: kind,
            model: identity.model,
            effort: self.effort(
                effort,
                on: kind,
                model: identity.model,
                models: models
            )
        )
    }

    public static func kind(
        ofModel model: String,
        running: AgentKind,
        models: [AgentKind: [AgentModel]] = [:]
    ) -> AgentKind {
        ModelIdentifier.resolve(model, models: models).kind ?? running
    }

    public static func effort(
        _ wanted: String,
        on kind: AgentKind,
        model: String,
        models: [AgentKind: [AgentModel]] = [:]
    ) -> String {
        models[kind]?.first { $0.id == model }?.resolvedEffort(preferring: wanted) ?? wanted
    }
}
