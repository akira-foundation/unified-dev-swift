import Foundation
import Testing
@testable import Core

@Suite("Pasted attachments")
struct PastedAttachmentTests {
    private func image(_ formats: PastedImageFormat...) -> PastedAttachment.Offer {
        PastedAttachment.Offer(types: formats.map(\.uti))
    }

    @Test("a screenshot copied rather than saved is attached as a picture")
    func plainScreenshot() {
        let plan = PastedAttachment.plan(items: [image(.png, .tiff)], hasText: false)
        #expect(plan == .images([PastedAttachment.Image(item: 0, format: .png)]))
    }

    @Test("a board carrying only TIFF is still a picture")
    func tiffOnly() {
        let plan = PastedAttachment.plan(items: [image(.tiff)], hasText: false)
        #expect(plan == .images([PastedAttachment.Image(item: 0, format: .tiff)]))
    }

    @Test("JPEG is taken as it is rather than as the TIFF beside it")
    func jpegBeatsTiff() {
        let plan = PastedAttachment.plan(items: [image(.jpeg, .tiff)], hasText: false)
        #expect(plan == .images([PastedAttachment.Image(item: 0, format: .jpeg)]))
    }

    @Test("a file beside the picture wins, because the file has a name")
    func fileBeatsImageData() {
        let offer = PastedAttachment.Offer(
            filePath: "/Users/freek/Library/Application Support/CleanShot/media/shot.png",
            types: [PastedImageFormat.png.uti]
        )
        #expect(PastedAttachment.plan(items: [offer], hasText: false)
            == .files(["/Users/freek/Library/Application Support/CleanShot/media/shot.png"]))
    }

    @Test("files win even when the board carries text as well")
    func filesBeatText() {
        let items = [
            PastedAttachment.Offer(filePath: "/tmp/one.png"),
            PastedAttachment.Offer(filePath: "/tmp/two.pdf"),
        ]
        #expect(PastedAttachment.plan(items: items, hasText: true) == .files(["/tmp/one.png", "/tmp/two.pdf"]))
    }

    @Test("words with a picture in them are still words")
    func textWithImageStaysText() {
        #expect(PastedAttachment.plan(items: [image(.png, .tiff)], hasText: true) == .text)
    }

    @Test("plain text is left to the text system")
    func plainText() {
        #expect(PastedAttachment.plan(items: [PastedAttachment.Offer()], hasText: true) == .text)
        #expect(PastedAttachment.plan(items: [], hasText: true) == .text)
        #expect(PastedAttachment.plan(items: [], hasText: false) == .text)
    }

    @Test("a board with nothing Unified Dev understands is left alone")
    func unknownFlavours() {
        let offer = PastedAttachment.Offer(types: ["com.adobe.pdf", "public.rtf"])
        #expect(PastedAttachment.plan(items: [offer], hasText: false) == .text)
    }

    @Test("several pictures on one board become several attachments")
    func multipleImages() {
        let plan = PastedAttachment.plan(items: [image(.png), image(.tiff), image(.jpeg)], hasText: false)
        #expect(plan == .images([
            PastedAttachment.Image(item: 0, format: .png),
            PastedAttachment.Image(item: 1, format: .tiff),
            PastedAttachment.Image(item: 2, format: .jpeg),
        ]))
    }

    @Test("an item with nothing on it is skipped rather than counted")
    func mixedItems() {
        let plan = PastedAttachment.plan(
            items: [PastedAttachment.Offer(types: ["public.rtf"]), image(.png)], hasText: false
        )
        #expect(plan == .images([PastedAttachment.Image(item: 1, format: .png)]))
    }

    @Test("only TIFF is worth rewriting, and it is written as PNG")
    func rewriting() {
        #expect(PastedImageFormat.tiff.isWorthReencoding)
        #expect(PastedImageFormat.tiff.written == .png)
        #expect(PastedImageFormat.png.isWorthReencoding == false)
        #expect(PastedImageFormat.png.written == .png)
        #expect(PastedImageFormat.jpeg.isWorthReencoding == false)
        #expect(PastedImageFormat.jpeg.written == .jpeg)
    }

    @Test("every format names a type the pasteboard uses and an extension a Mac writes")
    func utis() {
        #expect(PastedImageFormat.png.uti == "public.png")
        #expect(PastedImageFormat.jpeg.uti == "public.jpeg")
        #expect(PastedImageFormat.tiff.uti == "public.tiff")
        #expect(PastedImageFormat.jpeg.fileExtension == "jpg")
        for format in PastedImageFormat.allCases {
            #expect(format.uti.hasPrefix("public."))
            #expect(format.fileExtension.contains(".") == false)
        }
    }

    private var noon: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 20
        components.hour = 22
        components.minute = 29
        components.second = 20
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: components) ?? .distantPast
    }

    @Test("a pasted picture is named for when it was pasted")
    func name() {
        let name = PastedAttachment.filename(format: .png, at: noon, timeZone: .gmt)
        #expect(name == "Pasted 2026-08-20 at 22.29.20.png")
    }

    @Test("the name carries the format it is written as")
    func namePerFormat() {
        #expect(PastedAttachment.filename(format: .jpeg, at: noon, timeZone: .gmt)
            == "Pasted 2026-08-20 at 22.29.20.jpg")
        #expect(PastedAttachment.filename(format: .tiff, at: noon, timeZone: .gmt)
            == "Pasted 2026-08-20 at 22.29.20.tiff")
    }

    @Test("two pictures in the same second are two different names")
    func sameSecond() {
        var taken: Set<String> = []
        var names: [String] = []
        for _ in 0..<4 {
            let name = PastedAttachment.filename(format: .png, at: noon, avoiding: taken, timeZone: .gmt)
            taken.insert(name)
            names.append(name)
        }
        #expect(names == [
            "Pasted 2026-08-20 at 22.29.20.png",
            "Pasted 2026-08-20 at 22.29.20 2.png",
            "Pasted 2026-08-20 at 22.29.20 3.png",
            "Pasted 2026-08-20 at 22.29.20 4.png",
        ])
        #expect(Set(names).count == names.count)
    }

    @Test("a taken name is counted rather than overwritten")
    func uniquing() {
        #expect(PastedAttachment.uniqued("shot.png", avoiding: []) == "shot.png")
        #expect(PastedAttachment.uniqued("shot.png", avoiding: ["shot.png"]) == "shot 2.png")
        #expect(PastedAttachment.uniqued("shot.png", avoiding: ["shot.png", "shot 2.png"]) == "shot 3.png")
        #expect(PastedAttachment.uniqued("shot.png", avoiding: ["shot.png"]).hasSuffix(".png"))
        #expect(PastedAttachment.uniqued("notes", avoiding: ["notes"]) == "notes 2")
        #expect(PastedAttachment.uniqued("Pasted 2026-08-20 at 22.29.20.png", avoiding: ["Pasted 2026-08-20 at 22.29.20.png"])
            == "Pasted 2026-08-20 at 22.29.20 2.png")
    }

    @Test("the name is a filename and sorts by time")
    func nameIsSafe() {
        let early = PastedAttachment.filename(format: .png, at: noon, timeZone: .gmt)
        let later = PastedAttachment.filename(
            format: .png, at: noon.addingTimeInterval(3600), timeZone: .gmt
        )
        #expect(early < later)
        for name in [early, later] {
            #expect(name.contains("/") == false)
            #expect(name.contains(":") == false)
            #expect(name.hasPrefix(".") == false)
            #expect(name.hasPrefix("Pasted "))
        }
    }

    @Test("a pasted picture lands where git cannot see it")
    func shielded() {
        let name = PastedAttachment.filename(format: .png, at: noon, timeZone: .gmt)
        let path = "\(WorktreeScratch.attachments)/aB3xY9/\(name)"
        #expect(WorktreeScratch.isShielded(path))
    }
}
