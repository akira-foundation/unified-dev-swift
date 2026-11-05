import Foundation

public enum CanvasExportWriter {
    public static func write(_ plan: CanvasExportPlan, pictures: [CanvasFrameID: Data]) throws -> CanvasExportReport {
        var report = CanvasExportReport(directory: plan.directory, refused: plan.refused)
        try plan.checkDirectory()
        let folder = try CanvasExportDirectory.open(creating: plan.directory)

        for slide in plan.slides {
            guard let picture = pictures[slide.frame.id] else {
                report.failed.append(CanvasExportFailure(frame: slide.frame.name, reason: "the frame could not be drawn."))
                continue
            }
            do {
                try folder.write(picture, as: slide.file)
                report.written.append(slide.file)
            } catch {
                report.failed.append(CanvasExportFailure(frame: slide.frame.name, reason: error.localizedDescription))
            }
        }
        guard report.failed.isEmpty, report.refused.isEmpty else {
            report.olderKept = true
            return report
        }
        removeStale(keeping: Set(plan.slides.map(\.file)), in: folder, into: &report)
        return report
    }

    private static func removeStale(keeping current: Set<String>, in folder: borrowing CanvasExportDirectory, into report: inout CanvasExportReport) {
        for name in folder.names().sorted()
        where CanvasExportNames.isExportedFile(name) && !current.contains(name) {
            guard folder.isRegularFile(name) else { continue }
            do {
                try folder.remove(name)
                report.removed.append(name)
            } catch {
                report.failed.append(CanvasExportFailure(frame: name, reason: "the older picture could not be removed: \(error.localizedDescription)"))
            }
        }
    }
}

public enum CanvasExportWriteError: Error, Sendable, Equatable, LocalizedError {
    case directory(String)

    public var errorDescription: String? {
        switch self {
        case .directory(let reason): "The export folder could not be created. \(reason)"
        }
    }
}
