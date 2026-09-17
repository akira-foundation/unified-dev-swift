import Foundation

public enum TerminalSettingsCopy {
    public static func textSizeSource(override: Double?, ghostty: Double?) -> String {
        if override != nil {
            return "Set here, so it no longer follows Ghostty."
        }
        if let ghostty {
            return "Following your Ghostty configuration's font-size of \(Int(ghostty)) pt."
        }
        return "No Ghostty configuration was found, so terminals use the system monospaced size."
    }

    public static func persistence(isTmuxInstalled: Bool) -> String {
        guard isTmuxInstalled else {
            return "Requires tmux, which is not installed. Run `brew install tmux`."
        }
        return "Terminals come back on the next launch, with their scrollback and anything still "
            + "running in them. Archiving a workspace always stops its terminals."
    }
}
