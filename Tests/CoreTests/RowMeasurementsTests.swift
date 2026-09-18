import Testing
@testable import Core

@Suite("Remembering measured row heights between renders")
struct RowMeasurementsTests {
    @Test("a row is measured once for the same revision and width")
    func measuresOnce() {
        let measurements = RowMeasurements<[Double]>()
        var count = 0
        let first = measurements.measurement(for: "a", revision: 1, width: 400) { count += 1; return [18] }
        let second = measurements.measurement(for: "a", revision: 1, width: 400) { count += 1; return [36] }
        #expect(first == [18])
        #expect(second == [18])
        #expect(count == 1)
    }

    @Test("a row with nothing to measure is not measured again")
    func remembersNothing() {
        let measurements = RowMeasurements<[Double]>()
        var count = 0
        _ = measurements.measurement(for: "header", revision: 1, width: 400) { count += 1; return nil }
        let again = measurements.measurement(for: "header", revision: 1, width: 400) { count += 1; return nil }
        #expect(again == nil)
        #expect(count == 1)
    }

    @Test("a new width or revision measures again")
    func newLayoutMeasuresAgain() {
        let measurements = RowMeasurements<[Double]>()
        _ = measurements.measurement(for: "a", revision: 1, width: 400) { [18] }
        let wider = measurements.measurement(for: "a", revision: 1, width: 800) { [9] }
        let rebuilt = measurements.measurement(for: "a", revision: 2, width: 800) { [27] }
        #expect(wider == [9])
        #expect(rebuilt == [27])
    }
}
