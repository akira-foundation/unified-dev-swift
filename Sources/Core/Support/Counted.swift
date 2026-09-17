import Foundation

public enum Counted {
    public static func of(_ value: Int, _ noun: String, plural: String? = nil) -> String {
        "\(value.formatted()) \(word(value, noun, plural: plural))"
    }

    public static func word(_ value: Int, _ noun: String, plural: String? = nil) -> String {
        value == 1 ? noun : (plural ?? noun + "s")
    }
}
