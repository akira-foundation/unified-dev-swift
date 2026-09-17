import Foundation

public enum CodeColumns {
    public static func count(of line: String) -> Int {
        var count = 0
        for character in line {
            count += character == "\t" ? 4 : 1
        }
        return count
    }
}
