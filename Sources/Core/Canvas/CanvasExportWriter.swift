import Foundation

public enum CanvasExportWriter {
    public static func write(_ plan: CanvasExportPlan, pictures: [CanvasFrameID: Data]) throws -> CanvasExportReport {
        var report = CanvasExportReport(directory: plan.directory, refused: plan.refused)
        try plan.checkDirectory()
        let folder = URL(filePath: plan.directory, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw CanvasExportWriteError.directory(error.localizedDescription)
        }
        try plan.checkDirectory()

        for slide in plan.slides {
            guard let picture = pictures[slide.frame.id] else {
                report.failed.append(CanvasExportFailure(frame: slide.frame.name, reason: "the frame could not be drawn."))
                continue
            }
            do {
                try picture.write(to: folder.appending(path: slide.file), options: .atomic)
                report.written.append(slide.file)
            } catch {
                report.failed.append(CanvasExportFailure(frame: slide.frame.name, reason: error.localizedDescription))
            }
        }
        removeStale(keeping: Set(plan.slides.map(\.file)), in: folder, into: &report)
        return report
    }

    private static func removeStale(keeping current: Set<String>, in folder: URL, into report: inout CanvasExportReport) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names.sorted() where CanvasExportNames.isExportedFile(name) && !current.contains(name) {
            let url = folder.appending(path: name)
            let type = try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
            guard type == .typeRegular else { continue }
            do {
                try FileManager.default.removeItem(at: url)
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
