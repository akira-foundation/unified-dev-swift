import Foundation

public enum StoppedTurn {
    public static func closingRow<Rows: RandomAccessCollection>(
        in kinds: Rows
    ) -> Rows.Index? where Rows.Element == MessageKind {
        for index in kinds.indices.reversed() {
            switch kinds[index] {
            case .result: return index
            case .user, .crew: return nil
            default: continue
            }
        }
        return nil
    }
}
