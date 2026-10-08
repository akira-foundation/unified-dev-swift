import Foundation

extension Feedback {
    public static let maxImages = 5

    public static let maxImageBytes = 8 * 1024 * 1024

    public static let maxTotalImageBytes = 12 * 1024 * 1024

    public static func tooLargeMessage(name: String, bytes: Int) -> String {
        "\(name) is \(size(bytes)), and one image can be \(size(maxImageBytes)) at most. "
            + "Scale it down, or send a crop of the part that matters."
    }

    public static func tooManyMessage() -> String {
        "That is more than \(maxImages) images, which is as many as one report carries."
    }

    public static func tooMuchMessage() -> String {
        "That is more than \(size(maxTotalImageBytes)) of images all together, which is as much "
            + "as one report carries. Take one off, or send a smaller one."
    }

    public static func notAnImageMessage(name: String) -> String {
        "\(name) is not an image Unified Dev can send. PNG, JPEG, GIF, WebP and HEIC go; PDFs and SVGs "
            + "do not."
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }

    public struct Image: Sendable, Equatable {
        public let contentType: String
        public let data: Data

        public var filename: String { "attachment.\(Feedback.fileExtension(for: contentType))" }

        public init(contentType: String, data: Data) {
            self.contentType = Feedback.sniffedContentType(data) ?? Feedback.checkedContentType(contentType)
            self.data = data
        }
    }

    public static let imageContentTypes = [
        "image/png", "image/jpeg", "image/gif", "image/webp", "image/heic", "image/heif",
    ]

    static func checkedContentType(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return imageContentTypes.contains(trimmed) ? trimmed : "image/png"
    }

    public static func fileExtension(for contentType: String) -> String {
        switch contentType {
        case "image/png": "png"
        case "image/jpeg": "jpg"
        case "image/gif": "gif"
        case "image/webp": "webp"
        case "image/heic": "heic"
        case "image/heif": "heif"
        default: "png"
        }
    }

    public static func sniffedContentType(_ data: Data) -> String? {
        func starts(with bytes: [UInt8], at offset: Int = 0) -> Bool {
            guard data.count >= offset + bytes.count else { return false }
            let start = data.index(data.startIndex, offsetBy: offset)
            return Array(data[start..<data.index(start, offsetBy: bytes.count)]) == bytes
        }

        func ascii(at offset: Int, length: Int) -> String? {
            guard data.count >= offset + length else { return nil }
            let start = data.index(data.startIndex, offsetBy: offset)
            return String(bytes: data[start..<data.index(start, offsetBy: length)], encoding: .ascii)
        }

        if starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "image/png" }
        if starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if ascii(at: 0, length: 6) == "GIF87a" || ascii(at: 0, length: 6) == "GIF89a" { return "image/gif" }
        if ascii(at: 0, length: 4) == "RIFF", ascii(at: 8, length: 4) == "WEBP" { return "image/webp" }

        if ascii(at: 4, length: 4) == "ftyp", let brand = ascii(at: 8, length: 4) {
            if ["heic", "heix", "heim", "heis", "hevc", "hevx"].contains(brand) { return "image/heic" }
            if ["mif1", "msf1", "heif"].contains(brand) { return "image/heif" }
        }

        return nil
    }
}
