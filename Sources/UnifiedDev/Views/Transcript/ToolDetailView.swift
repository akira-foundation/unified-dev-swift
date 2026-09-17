import SwiftUI
import Core

struct ToolDetailView: View {
    var name: String
    var input: JSONValue
    var result: String?
    var isError: Bool = false
    var refusal: ToolRefusal?
    var refusalReason: String = ""
    var hasImages: Bool = false

    init(
        name: String,
        input: JSONValue,
        result: String? = nil,
        isError: Bool = false,
        refusal: ToolRefusal? = nil,
        refusalReason: String = "",
        hasImages: Bool = false
    ) {
        self.name = name
        self.input = input
        self.result = result
        self.isError = isError
        self.refusal = refusal
        self.refusalReason = refusalReason
        self.hasImages = hasImages
    }

    init(use: AgentToolUse, result: AgentToolResult?, refusal: ToolRefusal? = nil, refusalReason: String = "") {
        self.init(
            name: use.name,
            input: use.input,
            result: result?.text,
            isError: result?.isError ?? false,
            refusal: refusal ?? result?.refusal,
            refusalReason: refusalReason,
            hasImages: result?.hasImages ?? false
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TranscriptLayout.block) {
            ToolInputView(name: name, input: input)

            if let refusal {
                ToolRefusalView(refusal: refusal, reason: refusalReason.isEmpty ? (result ?? "") : refusalReason)
            } else if let result, !result.isEmpty {
                ToolResultView(text: result, isError: isError)
            } else if hasImages {
                DetailCaption(text: "The tool returned an image.")
            }
        }
        .padding(.top, TranscriptLayout.inset)
        .textSelection(.enabled)
    }
}
