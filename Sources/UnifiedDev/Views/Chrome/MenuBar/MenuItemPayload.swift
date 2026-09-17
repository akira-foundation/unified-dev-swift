import AppKit

final class MenuItemPayload<Value>: NSObject {
    let value: Value

    init(_ value: Value) { self.value = value }
}

extension NSMenuItem {
    func represent<Value>(_ value: Value) {
        representedObject = MenuItemPayload(value)
    }

    func represented<Value>(_ type: Value.Type) -> Value? {
        (representedObject as? MenuItemPayload<Value>)?.value
    }
}
