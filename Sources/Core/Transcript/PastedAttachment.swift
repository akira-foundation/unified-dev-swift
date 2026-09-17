import Foundation

public enum PastedImageFormat: String, Sendable, CaseIterable {
    case png
    case jpeg
    case tiff

    public var uti: String {
        switch self {
        case .png: "public.png"
        case .jpeg: "public.jpeg"
        case .tiff: "public.tiff"
        }
    }

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .tiff: "tiff"
        }
    }

    public var isWorthReencoding: Bool { self == .tiff }

    public var written: PastedImageFormat { isWorthReencoding ? .png : self }

    public static func best(of utis: [String]) -> PastedImageFormat? {
        allCases.first { format in utis.contains(format.uti) }
    }
}

public enum PastedAttachment {
    public struct Offer: Sendable, Equatable {
        public var filePath: String?
        public var types: [String]

        public init(filePath: String? = nil, types: [String] = []) {
            self.filePath = filePath
            self.types = types
        }

        public var imageFormat: PastedImageFormat? { PastedImageFormat.best(of: types) }
    }

    public struct Image: Sendable, Equatable {
        public var item: Int
        public var format: PastedImageFormat

        public init(item: Int, format: PastedImageFormat) {
            self.item = item
            self.format = format
        }
    }

    public enum Plan: Sendable, Equatable {
        case files([String])
        case images([Image])
        case text
    }

    public static func plan(items: [Offer], hasText: Bool) -> Plan {
        let files = items.compactMap(\.filePath)
        if !files.isEmpty { return .files(files) }

        guard !hasText else { return .text }

        let images = items.enumerated().compactMap { index, item in
            item.imageFormat.map { Image(item: index, format: $0) }
        }
        return images.isEmpty ? .text : .images(images)
    }

    public static func filename(
        format: PastedImageFormat,
        at date: Date = .now,
        avoiding taken: Set<String> = [],
        timeZone: TimeZone = .current
    ) -> String {
        uniqued("Pasted \(timestamp(date, in: timeZone)).\(format.fileExtension)", avoiding: taken)
    }

    public static func uniqued(_ name: String, avoiding taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        for counter in 2...999 {
            let candidate = "\(base) \(counter)\(suffix)"
            if !taken.contains(candidate) { return candidate }
        }
        return "\(base) \(UUID().uuidString.prefix(6))\(suffix)"
    }

    public static func timestamp(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: date)
    }
}
