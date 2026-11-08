import Core
import SwiftUI

struct NotificationBellButton: View {
    let inbox: NotificationInboxModel
    let profiles: [Profile]

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            if let badge = NotificationBellReading.badge(unseen: inbox.unseen) {
                Label(badge, systemImage: "bell.badge")
                    .labelStyle(.titleAndIcon)
            } else {
                Image(systemName: "bell")
            }
        }
        .help("Notifications")
        .accessibilityLabel(NotificationBellReading.accessibilityLabel(unseen: inbox.unseen))
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            NotificationBellList(
                rows: inbox.rows,
                profiles: profiles,
                now: Date(),
                onOpen: { row in
                    isShowing = false
                    Task { await inbox.open(row) }
                },
                onMarkAll: inbox.markAllRead
            )
        }
    }
}

struct NotificationBellList: View {
    let rows: [InboxNotification]
    let profiles: [Profile]
    let now: Date
    let onOpen: (InboxNotification) -> Void
    let onMarkAll: () -> Void

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView("No Notifications", systemImage: "bell")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            NotificationBellRow(
                                reading: InboxRowReading(row, profileName: profile(of: row)?.name, now: now),
                                isUnseen: row.counts,
                                profile: profile(of: row),
                                onOpen: { onOpen(row) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .frame(width: 360, height: 420)
    }

    private var header: some View {
        HStack {
            Text("Notifications")
                .font(.headline)
            Spacer()
            Button("Mark All as Read", action: onMarkAll)
                .buttonStyle(.borderless)
                .disabled(NotificationInbox.unseenCount(rows) == 0)
        }
        .padding(12)
    }

    private func profile(of row: InboxNotification) -> Profile? {
        profiles.first { $0.id == row.profileID }
    }
}

private struct NotificationBellRow: View {
    let reading: InboxRowReading
    let isUnseen: Bool
    let profile: Profile?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                mark
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reading.title)
                        .fontWeight(isUnseen ? .semibold : .regular)
                        .lineLimit(1)
                    Text(reading.origin)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(reading.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(reading.age)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isUnseen {
                        Circle()
                            .fill(.tint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .opacity(reading.isDimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!reading.opens)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.accessibilityLabel)
        .accessibilityAddTraits(reading.opens ? .isButton : [])
    }

    @ViewBuilder private var mark: some View {
        if let profile {
            ProfileMark(symbol: profile.symbol, colour: profile.colour)
        } else {
            Image(systemName: "bell")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
