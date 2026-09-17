import Testing
@testable import Core

@Suite("Naming an attached file")
struct PromptAttachmentsTests {
    @Test("an ordinary name is left exactly as it is")
    func ordinaryNamesSurvive() {
        #expect(PromptAttachments.safeFilename("Screenshot 2026-08-24.png") == "Screenshot 2026-08-24.png")
        #expect(PromptAttachments.safeFilename("café ünïcode.txt") == "café ünïcode.txt")
        #expect(PromptAttachments.safeFilename("report (final) v2.pdf") == "report (final) v2.pdf")
    }

    @Test("a separator cannot make the name mean another directory")
    func separatorsCannotEscape() {
        #expect(!PromptAttachments.safeFilename("a/b/c.png").contains("/"))
        #expect(PromptAttachments.safeFilename("a/b/c.png") == "a-b-c.png")
        #expect(!PromptAttachments.safeFilename("Volumes:disk:file.txt").contains(":"))
    }

    @Test("no name comes out as a dot, a double dot, or hidden")
    func dotsCannotSurvive() {
        #expect(PromptAttachments.safeFilename("..") == "attachment")
        #expect(PromptAttachments.safeFilename(".") == "attachment")
        #expect(PromptAttachments.safeFilename("....") == "attachment")
        #expect(PromptAttachments.safeFilename("../../etc/passwd") == "-..-etc-passwd")
        #expect(PromptAttachments.safeFilename(".env") == "env")
        for name in ["..", ".", "....", "../..", "./.", ".hidden"] {
            #expect(!PromptAttachments.safeFilename(name).hasPrefix("."))
        }
    }

    @Test("a name that cleans away to nothing gets one")
    func emptyNamesGetAName() {
        #expect(PromptAttachments.safeFilename("") == "attachment")
        #expect(PromptAttachments.safeFilename("   ") == "attachment")
        #expect(PromptAttachments.safeFilename("\n\t ") == "attachment")
        #expect(!PromptAttachments.safeFilename("///").isEmpty)
    }

    @Test("a copy lands under Unified Dev's scratch folder, keyed by its id")
    func destinationsAreInsideTheScratchFolder() {
        let path = PromptAttachments.destination(filename: "notes.md", id: "aB3xY9")
        #expect(path == "\(WorktreeScratch.attachments)/aB3xY9/notes.md")
        #expect(path.hasPrefix(WorktreeScratch.attachments))
    }

    @Test("a hostile name cannot climb out of the folder it is written into")
    func destinationsCannotEscape() {
        for hostile in ["../../../../etc/passwd", "..", "a/../../b", ".ssh/authorized_keys"] {
            let path = PromptAttachments.destination(filename: hostile, id: "aB3xY9")
            #expect(path.hasPrefix("\(WorktreeScratch.attachments)/aB3xY9/"))
            #expect(path.components(separatedBy: "/").count
                == WorktreeScratch.attachments.components(separatedBy: "/").count + 2)
        }
    }

    @Test("an id is six characters of an alphabet a path and a URL both accept")
    func idsAreShortAndSafe() {
        let allowed = Set("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<200 {
            let id = PromptAttachments.newShortID()
            #expect(id.count == 6)
            #expect(id.allSatisfy(allowed.contains))
            #expect(PromptAttachments.safeFilename(id) == id)
        }
    }

    @Test("ids do not repeat in any quantity anybody attaches")
    func idsDoNotCollide() {
        let ids = Set((0..<500).map { _ in PromptAttachments.newShortID() })
        #expect(ids.count == 500)
    }
}
