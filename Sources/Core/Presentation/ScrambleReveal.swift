import Foundation

public enum ScrambleReveal {
    public static let steps = 16
    public static let interval = Duration.milliseconds(30)

    static let lowercase = Array("abcdeghknopqsuvxyz")
    static let uppercase = Array("ABCDEGHKNOPQSUVXYZ")
    static let digits = Array("0123456789")

    public static func frame(target: String, step: Int, seed: UInt64) -> String {
        guard step < steps else { return target }
        let characters = Array(target)
        guard !characters.isEmpty else { return target }

        let tick = max(0, step)
        let resolved = resolvedCount(of: characters.count, step: tick)

        var output = String()
        output.reserveCapacity(target.count)
        for (index, character) in characters.enumerated() {
            if index < resolved || character.isWhitespace {
                output.append(character)
            } else {
                output.append(scramble(character, index: index, step: tick, seed: seed))
            }
        }
        return output
    }

    static func resolvedCount(of length: Int, step: Int) -> Int {
        guard step > 0 else { return 0 }
        guard step < steps else { return length }
        let scaled = (length * step + steps - 1) / steps
        return min(length, scaled)
    }

    static func scramble(_ character: Character, index: Int, step: Int, seed: UInt64) -> Character {
        let alphabet: [Character]
        if character.isNumber {
            alphabet = digits
        } else if character.isUppercase {
            alphabet = uppercase
        } else if character.isLetter {
            alphabet = lowercase
        } else {
            return character
        }

        var roll = Int(mix(seed, UInt64(step) &* 1_000_003 &+ UInt64(index)) % UInt64(alphabet.count))
        if alphabet[roll] == character {
            roll = (roll + 1) % alphabet.count
        }
        return alphabet[roll]
    }

    static func mix(_ seed: UInt64, _ counter: UInt64) -> UInt64 {
        var z = seed &+ (counter &* 0x9E37_79B9_7F4A_7C15)
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
