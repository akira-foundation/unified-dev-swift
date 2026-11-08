import SwiftUI
import Core

extension View {
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
