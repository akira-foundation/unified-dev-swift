import Foundation

public enum ReviewCollapse {
    public static func collapsed(
        _ collapsed: Set<String>, viewed: Set<String>, wasViewed: Set<String>
    ) -> Set<String> {
        collapsed
            .union(viewed.subtracting(wasViewed))
            .subtracting(wasViewed.subtracting(viewed))
    }
}
