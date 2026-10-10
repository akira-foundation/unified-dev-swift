import Foundation

public enum BrowserScriptValue: Sendable, Equatable {
    case text(String)
    case number(Int)
    case flag(Bool)
}

extension [String: BrowserScriptValue] {
    public func mapped() -> [String: Any] {
        mapValues { value -> Any in
            switch value {
            case .text(let text): text
            case .number(let number): number
            case .flag(let flag): flag
            }
        }
    }
}
