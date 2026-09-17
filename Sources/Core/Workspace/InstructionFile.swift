import Foundation

public enum InstructionFile {
    public static func isFile(_ relative: String, in worktree: String) -> Bool {
        let full = (worktree as NSString).appendingPathComponent(relative)
        var isDirectory: ObjCBool = false
        let manager = FileManager.default
        guard manager.fileExists(atPath: full, isDirectory: &isDirectory), !isDirectory.boolValue
        else { return false }
        return manager.isReadableFile(atPath: full)
    }

    public static func asking(_ text: String, toFollow path: String) -> String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence = "Follow the instructions in \(AttachmentDraft.token(for: path))."
        guard !body.isEmpty else { return sentence }
        return "\(body)\n\n\(sentence)"
    }
}
