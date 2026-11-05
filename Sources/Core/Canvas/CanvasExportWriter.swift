import Foundation

public enum CanvasExportWriter {
    public static func write(_ plan: CanvasExportPlan, pictures: [CanvasFrameID: Data]) throws -> CanvasExportReport {
        var report = CanvasExportReport(directory: plan.directory, refused: plan.refused)
        try plan.checkDirectory()
        let folder = try CanvasExportDirectory.open(creating: plan.directory)

        var manifest = CanvasExportManifest(reading: folder.read(CanvasExportManifest.fileName, upTo: CanvasExportManifest.largestBytes))

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
        let written = Set(report.written)
        guard report.failed.isEmpty, report.refused.isEmpty else {
            report.olderKept = true
            manifest.record(manifest.files(of: plan.document).union(written), for: plan.document)
            save(manifest, in: folder, into: &report)
            return report
        }
        let remaining = removeStale(manifest.removable(for: plan.document, keeping: written), in: folder, into: &report)
        manifest.record(written.union(remaining), for: plan.document)
        save(manifest, in: folder, into: &report)
        return report
    }

    private static func removeStale(_ stale: Set<String>, in folder: borrowing CanvasExportDirectory, into report: inout CanvasExportReport) -> Set<String> {
        var remaining: Set<String> = []
        for name in folder.names().sorted()
        where stale.contains(name) && CanvasExportNames.isExportedFile(name) && folder.isRegularFile(name) {
            do {
                try folder.remove(name)
                report.removed.append(name)
            } catch {
                remaining.insert(name)
                report.failed.append(CanvasExportFailure(frame: name, reason: "the older picture could not be removed: \(error.localizedDescription)"))
            }
        }
        return remaining
    }

    private static func save(_ manifest: CanvasExportManifest, in folder: borrowing CanvasExportDirectory, into report: inout CanvasExportReport) {
        do {
            try folder.write(try manifest.encoded(), as: CanvasExportManifest.fileName)
        } catch {
            report.failed.append(CanvasExportFailure(
                frame: "the list of this export's pictures",
                reason: "\(error.localizedDescription) A later export will leave these pictures in the folder."
            ))
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
