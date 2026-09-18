import Foundation

enum TestDefaults {
    static func make(_ label: String) -> (name: String, defaults: UserDefaults) {
        let name = (TestProcessScratch.directory("defaults") as NSString).appendingPathComponent(label)
        return (name, UserDefaults(suiteName: name)!)
    }
}
