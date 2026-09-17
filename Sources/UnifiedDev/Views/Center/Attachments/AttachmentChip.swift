import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AttachmentChip: View {
    var attachment: PromptAttachment
    var worktree: String
    var onOpen: (@MainActor () -> Void)?
    var onOpenInNewTab: (@MainActor () -> Void)?
    var onRemove: (@MainActor () -> Void)?
    var onHover: (@MainActor (Bool) -> Void)?
    var onPreview: (@MainActor (CGRect?) -> Void)?
    var verifiesOnDisk = true

    @State private var isHovered = false
    @State private var isMissing = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var frameInWindow: CGRect = .zero

    @Environment(\.isOnEmphasizedSelection) private var isOnSelection

    static let height: CGFloat = Metrics.controlHeight
    static let slot: CGFloat = 14
    private static let maxNameWidth: CGFloat = 150
    private static var hoverDelay: Duration { Motion.hoverCardDelay }

    var body: some View {
        HStack(spacing: Metrics.spacingSmall) {
            leading

            Text(attachment.filename)
                .font(Typo.caption)
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: Self.maxNameWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .imageScale(.small)
                    .foregroundStyle(isOnSelection ? Palette.selectedEmphasizedText : Palette.warning)
                    .help("This file is no longer on disk")
                    .accessibilityLabel("Missing")
            }
        }
        .padding(.horizontal, Metrics.spacing)
        .frame(height: Self.height)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .fill(plate)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.cornerSmall)
                .strokeBorder(stroke, lineWidth: Metrics.outline)
        }
        .background { probe }
        .background(HoverQuickLook(url: url))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerSmall))
        .modifier(TapWhenOffered(count: 2, action: onOpenInNewTab))
        .modifier(TapWhenOffered(action: onOpen))
        .contextMenu { menu }
        .onHover(perform: hover(_:))
        .help(attachment.path)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(attachment.filename)
        .accessibilityHint(onOpen == nil ? "" : "Opens \(attachment.path) in a tab")
        .modifier(PresenceProbe(path: verifiesOnDisk ? url.path : nil, isMissing: $isMissing))
        .onDisappear { hoverTask?.cancel() }
    }

    @ViewBuilder
    private var menu: some View {
        if let onOpenInNewTab {
            Button("Open in New Tab", action: onOpenInNewTab)
        }
        Button("Quick Look") { HoverQuickLookController.shared.show(url) }
        Button("Reveal in Finder") { Reveal.inFinder(url.path) }
        Button("Copy path") { Clipboard.copy(attachment.path) }
    }

    private var plate: Color {
        guard isOnSelection else {
            return isHovered ? Palette.hover : Palette.surfaceRaised
        }
        return Palette.selectedEmphasizedText.opacity(isHovered ? 0.3 : 0.2)
    }

    private var stroke: Color {
        isOnSelection ? Palette.selectedEmphasizedText.opacity(0.35) : Palette.border
    }

    private var nameColor: Color {
        guard isOnSelection else {
            return isMissing ? Palette.textTertiary : Palette.textPrimary
        }
        return isMissing
            ? Palette.selectedEmphasizedText.opacity(0.75)
            : Palette.selectedEmphasizedText
    }

    @ViewBuilder
    private var leading: some View {
        if isHovered, let onRemove {
            ChipRemoveButton(
                diameter: Self.slot,
                label: "Remove \(attachment.filename)",
                action: onRemove
            )
        } else {
            Image(nsImage: FileTypeIcon.icon(for: attachment.filename))
                .resizable()
                .frame(width: Self.slot, height: Self.slot)
                .accessibilityHidden(true)
        }
    }

    private var url: URL { attachment.url(in: worktree) }

    @ViewBuilder
    private var probe: some View {
        if onPreview != nil, isHovered {
            Color.clear
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    frameInWindow = $0
                }
        }
    }

    private func hover(_ hovering: Bool) {
        isHovered = hovering
        hoverTask?.cancel()

        guard onHover != nil || onPreview != nil else { return }
        guard hovering else {
            onHover?(false)
            onPreview?(nil)
            return
        }
        hoverTask = Task {
            try? await Task.sleep(for: Self.hoverDelay)
            guard !Task.isCancelled else { return }
            onHover?(true)
            if frameInWindow != .zero { onPreview?(frameInWindow) }
        }
    }
}

@MainActor
enum FileTypeIcon {
    private static var cache: [String: NSImage] = [:]

    static func icon(for filename: String) -> NSImage {
        let ext = (filename as NSString).pathExtension.lowercased()
        if let cached = cache[ext] { return cached }

        let type = ext.isEmpty ? UTType.data : (UTType(filenameExtension: ext) ?? .data)
        let icon = NSWorkspace.shared.icon(for: type)
        cache[ext] = icon
        return icon
    }
}

private struct TapWhenOffered: ViewModifier {
    var count: Int = 1
    var action: (@MainActor () -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(count: count, perform: action)
        } else {
            content
        }
    }
}

private struct PresenceProbe: ViewModifier {
    var path: String?
    @Binding var isMissing: Bool

    func body(content: Content) -> some View {
        if let path {
            content.task(id: path) {
                isMissing = !FileManager.default.fileExists(atPath: path)
            }
        } else {
            content
        }
    }
}
