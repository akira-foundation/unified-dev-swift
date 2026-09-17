import Foundation
import Observation
import Core

@MainActor
@Observable
final class ComposerOutputStyleCatalog {
    private(set) var styles: [OutputStyle] = OutputStyle.builtIns

    private var loadedPath: String?
    private var loadedAt: Date?
    private var running: Task<[OutputStyle], Never>?
    private var runningPath: String?

    static let stalenessWindow: TimeInterval = 3

    private static var byProject: [String: ComposerOutputStyleCatalog] = [:]

    static func shared(for project: String?) -> ComposerOutputStyleCatalog {
        let key = project ?? ""
        if let held = byProject[key] { return held }
        let made = ComposerOutputStyleCatalog()
        byProject[key] = made
        return made
    }

    func refreshIfStale(project: String?, now: Date = Date()) async {
        if loadedPath == project,
           let loadedAt,
           now.timeIntervalSince(loadedAt) < Self.stalenessWindow {
            return
        }
        await scan(project: project)
    }

    func options(includingCurrent current: String) -> [ComposerOption] {
        let known = styles.map { style in
            ComposerOption(
                id: style.name,
                label: style.name == OutputStyle.defaultName ? "Default" : style.name,
                detail: style.detail
            )
        }
        return ComposerOption.adding([current], to: known)
    }

    func detail(of name: String) -> String? {
        styles.first { $0.name == name }?.detail
    }

    private func scan(project: String?) async {
        let task: Task<[OutputStyle], Never>
        if let running, runningPath == project {
            task = running
        } else {
            let home = NSHomeDirectory()
            task = Task.detached(priority: .utility) {
                OutputStyleIndex.discover(home: home, project: project)
            }
            running = task
            runningPath = project
        }

        let found = await task.value
        guard running == task else { return }
        running = nil
        runningPath = nil

        loadedPath = project
        loadedAt = Date()
        if found != styles { styles = found }
    }
}
