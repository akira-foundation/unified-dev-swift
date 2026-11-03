import SwiftUI
import Core

extension View {
    func opensTranscriptLinks() -> some View {
        modifier(TranscriptLinkOpening())
    }

    @ViewBuilder
    func transcriptLinkMenu(_ addresses: [String]) -> some View {
        if addresses.isEmpty {
            self
        } else {
            contextMenu {
                ForEach(addresses.indices, id: \.self) { index in
                    let address = addresses[index]
                    Button(addresses.count == 1 ? "Copy Link" : "Copy \(LinkPolicy.shortened(address))") {
                        TranscriptLink.copy(address)
                    }
                }
            }
        }
    }

    func transcriptLinkActions(_ addresses: [String]) -> some View {
        modifier(TranscriptLinkAccessibility(addresses: addresses))
    }
}

private struct TranscriptLinkOpening: ViewModifier {
    @Environment(\.markdownLinkActions) private var actions

    func body(content: Content) -> some View {
        content.environment(\.openURL, OpenURLAction { [actions] url in
            guard LinkPolicy.opens(url) else { return .discarded }
            actions.follow(url)
            return .handled
        })
    }
}

private struct TranscriptLinkAccessibility: ViewModifier {
    var addresses: [String]

    @Environment(\.markdownLinkActions) private var actions

    @ViewBuilder
    func body(content: Content) -> some View {
        if addresses.isEmpty {
            content
        } else {
            content.accessibilityActions {
                ForEach(addresses.indices, id: \.self) { index in
                    let address = addresses[index]
                    Button(addresses.count == 1 ? "Open Link" : "Open \(LinkPolicy.shortened(address))") {
                        guard let url = URL(string: address), LinkPolicy.opens(url) else { return }
                        actions.follow(url)
                    }
                }
            }
        }
    }
}
