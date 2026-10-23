public enum CaptureWait {
    public static func ticks(seconds: Int, everyMilliseconds step: Int) -> Int {
        let asked = max(1, seconds)
        let tick = max(1, step)
        return max(1, asked * 1_000 / tick)
    }
}
