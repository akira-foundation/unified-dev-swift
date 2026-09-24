import AppKit
import Core

extension ComposerTextView {
    static func attachables(on pasteboard: NSPasteboard) -> [AttachmentSource] {
        let items = pasteboard.pasteboardItems ?? []
        switch plan(for: items, on: pasteboard) {
        case .text:
            return []
        case .files(let paths):
            return paths.map { .file(URL(filePath: $0)) }
        case .images(let images):
            var taken: Set<String> = []
            return images.compactMap { image in
                guard items.indices.contains(image.item),
                      let data = items[image.item].data(
                          forType: NSPasteboard.PasteboardType(image.format.uti)
                      ),
                      !data.isEmpty
                else { return nil }
                let name = PastedAttachment.filename(
                    format: image.format.written, avoiding: taken
                )
                taken.insert(name)
                return .image(data, format: image.format, named: name)
            }
        }
    }

    static func hasAttachables(on pasteboard: NSPasteboard) -> Bool {
        plan(for: pasteboard.pasteboardItems ?? [], on: pasteboard) != .text
    }

    private static func plan(
        for items: [NSPasteboardItem], on pasteboard: NSPasteboard
    ) -> PastedAttachment.Plan {
        let offers = items.map { item in
            PastedAttachment.Offer(
                filePath: item.fileURL()?.path,
                types: item.types.map(\.rawValue)
            )
        }
        let hasText = (pasteboard.string(forType: .string)?.isEmpty == false)
        return PastedAttachment.plan(items: offers, hasText: hasText)
    }
}

private extension NSPasteboardItem {
    func fileURL() -> URL? {
        guard let string = string(forType: .fileURL),
              let url = URL(string: string), url.isFileURL else { return nil }
        return url.standardizedFileURL
    }
}
