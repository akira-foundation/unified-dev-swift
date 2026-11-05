import Foundation

public enum ProfileChoices {
    public struct Symbol: Identifiable, Equatable, Sendable {
        public let name: String
        public let label: String
        public var id: String { name }

        init(_ name: String, _ label: String) {
            self.name = name
            self.label = label
        }
    }

    public static let symbols: [Symbol] = [
        Symbol("square.stack.3d.up", "Stack"),
        Symbol("briefcase", "Briefcase"),
        Symbol("building.2", "Building"),
        Symbol("house", "House"),
        Symbol("person", "Person"),
        Symbol("person.2", "People"),
        Symbol("hammer", "Hammer"),
        Symbol("wrench.and.screwdriver", "Tools"),
        Symbol("terminal", "Terminal"),
        Symbol("laptopcomputer", "Laptop"),
        Symbol("server.rack", "Server"),
        Symbol("cube", "Cube"),
        Symbol("shippingbox", "Box"),
        Symbol("leaf", "Leaf"),
        Symbol("flame", "Flame"),
        Symbol("bolt", "Bolt"),
        Symbol("star", "Star"),
        Symbol("heart", "Heart"),
        Symbol("flag", "Flag"),
        Symbol("bookmark", "Bookmark"),
        Symbol("book", "Book"),
        Symbol("graduationcap", "Graduation Cap"),
        Symbol("globe", "Globe"),
        Symbol("paintbrush", "Paintbrush"),
    ]

    private static let colourNames = [
        "4C8DF6": "Blue", "22A06B": "Green", "E2725B": "Coral", "9B6DE0": "Purple", "D9A21B": "Amber",
        "2FA8A8": "Teal", "D8608C": "Pink", "6C7A89": "Slate", "E06C2A": "Orange", "5B8C2A": "Olive",
    ]

    public static func colourName(_ hex: String) -> String {
        colourNames[hex] ?? "#\(hex)"
    }
}
