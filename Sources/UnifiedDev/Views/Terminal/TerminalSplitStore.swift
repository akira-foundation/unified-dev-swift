import SwiftUI
import Observation
import Core

@MainActor
@Observable
final class TerminalSplitStore {
    static let shared = TerminalSplitStore()

    private var layouts: [String: SplitLayout] = [:]

    private var focusRequests: [String: Int] = [:]

    private static let keyPrefix = TabDefaults.splitPrefix

    private init() {
        let defaults = UserDefaults.standard
        let snapshot = DefaultsSnapshot.own(defaults, name: Bundle.main.bundleIdentifier)
        for (key, value) in snapshot where key.hasPrefix(Self.keyPrefix) {
            guard let encoded = value as? String, let layout = SplitLayout(encoded: encoded) else {
                continue
            }
            layouts[String(key.dropFirst(Self.keyPrefix.count))] = layout
        }
    }

    func layout(for ownerID: String) -> SplitLayout {
        layouts[ownerID] ?? SplitLayout(pane: ownerID)
    }

    func focusRequest(for ownerID: String) -> Int {
        focusRequests[ownerID] ?? 0
    }

    func panes(of ownerID: String) -> [String] {
        layout(for: ownerID).panes
    }

    @discardableResult
    func split(_ ownerID: String, axis: SplitAxis) -> String? {
        var layout = layout(for: ownerID)
        let pane = newID()
        guard layout.split(layout.focus, axis: axis, into: pane) else { return nil }
        apply(layout, to: ownerID, movingFocus: true)
        return pane
    }

    func close(pane: String, in ownerID: String) -> Bool {
        var layout = layout(for: ownerID)
        let hadFocus = layout.focus == pane
        guard layout.close(pane) else { return false }
        apply(layout, to: ownerID, movingFocus: hadFocus)
        return true
    }

    func focus(_ pane: String, in ownerID: String) {
        var layout = layout(for: ownerID)
        guard layout.focus != pane, layout.setFocus(pane) else { return }
        apply(layout, to: ownerID, movingFocus: false)
    }

    func moveFocus(_ direction: SplitDirection, in ownerID: String) -> Bool {
        var layout = layout(for: ownerID)
        guard layout.moveFocus(direction) else { return false }
        apply(layout, to: ownerID, movingFocus: true)
        return true
    }

    func toggleZoom(in ownerID: String) -> Bool {
        var layout = layout(for: ownerID)
        guard layout.toggleZoom() else { return false }
        apply(layout, to: ownerID, movingFocus: true)
        return true
    }

    func setRatio(_ ratio: Double, at path: [Int], in ownerID: String) {
        var layout = layout(for: ownerID)
        guard layout.setRatio(ratio, at: path) else { return }
        layouts[ownerID] = layout
    }

    func persistRatio(in ownerID: String) {
        guard let layout = layouts[ownerID] else { return }
        persist(layout, for: ownerID)
    }

    func discard(ownerID: String) {
        layouts[ownerID] = nil
        focusRequests[ownerID] = nil
        UserDefaults.standard.removeObject(forKey: Self.keyPrefix + ownerID)
    }

    private func apply(_ layout: SplitLayout, to ownerID: String, movingFocus: Bool) {
        layouts[ownerID] = layout
        if movingFocus { focusRequests[ownerID] = focusRequest(for: ownerID) + 1 }
        persist(layout, for: ownerID)
    }

    private func persist(_ layout: SplitLayout, for ownerID: String) {
        let defaults = UserDefaults.standard
        let key = Self.keyPrefix + ownerID

        guard layout.paneCount > 1, let encoded = layout.encoded else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(encoded, forKey: key)
    }
}
