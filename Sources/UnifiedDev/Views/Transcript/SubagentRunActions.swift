import Core

struct SubagentRunActions {
    var isLive: (String) -> Bool
    var open: (String, Bool, Bool) -> Void
}
