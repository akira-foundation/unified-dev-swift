import Foundation

struct CanvasRevisionFloor: Sendable {
    private var highest: [String: Int] = [:]

    mutating func note(_ document: CanvasDocument) {
        for frame in document.frames { highest[frame.id.rawValue] = max(highest[frame.id.rawValue] ?? frame.revision, frame.revision) }
        for element in document.elements { highest[element.id.rawValue] = max(highest[element.id.rawValue] ?? element.revision, element.revision) }
    }

    func raising(_ document: CanvasDocument) -> CanvasDocument {
        var raised = document
        for index in raised.frames.indices {
            raised.frames[index].revision = raise(raised.frames[index].revision, id: raised.frames[index].id.rawValue)
        }
        for index in raised.elements.indices {
            raised.elements[index].revision = raise(raised.elements[index].revision, id: raised.elements[index].id.rawValue)
        }
        return raised
    }

    private func raise(_ revision: Int, id: String) -> Int {
        guard let floor = highest[id] else { return revision }
        return max(revision, floor) + 1
    }
}
