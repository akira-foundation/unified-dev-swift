import AppKit
import SwiftUI
import Core

struct OpenInSettingsSection: View {
    @State private var apps: [ExternalApp] = []
    @State private var locations: [String: URL] = [:]
    @State private var refusal: String?

    var body: some View {
        Section("Open in") {
            ForEach(apps) { app in
                row(app)
            }

            Button("Add Application…") {
                Task { await add() }
            }

            if let refusal {
                Text(refusal).foregroundStyle(Palette.negative)
            }

            Text(
                "Every editor, terminal and git client Unified Dev knows is already offered once it is "
                + "installed. Add one Unified Dev does not know and it joins every Open in menu, "
                + "including Open Worktree in."
            )
            .settingsFootnote()
        }
        .onAppear(perform: load)
    }

    private func row(_ app: ExternalApp) -> some View {
        let url = locations[app.bundleID]
        return HStack(spacing: Metrics.gutter) {
            if let url {
                Image(nsImage: InstalledApps.icon(at: url))
            } else {
                Image(systemName: "app.dashed")
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(app.name)
                if url == nil {
                    Text("Not installed").settingsFootnote()
                }
            }
            .lineLimit(1)
            Spacer()
            Picker("Offered for", selection: targets(of: app)) {
                Text("Files and folders").tag(OpenTargets.both)
                Text("Folders only").tag(OpenTargets.folder)
            }
            .labelsHidden()
            .fixedSize()
            Button("Remove") { remove(app) }
        }
    }

    private func targets(of app: ExternalApp) -> Binding<OpenTargets> {
        Binding(
            get: { app.targets },
            set: { targets in
                OpenInCustomApps().setTargets(targets, forBundleID: app.bundleID)
                reload()
            }
        )
    }

    private func add() async {
        refusal = nil
        guard let url = await ApplicationPicker.choose() else { return }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            refusal = "\(url.lastPathComponent) has no bundle identifier, so Unified Dev cannot open "
                + "anything with it."
            return
        }
        let app = ExternalApp(
            bundleID: bundleID,
            name: InstalledApps.name(of: url),
            targets: .both,
            fileName: url.lastPathComponent
        )
        switch OpenInCustomApps().add(app) {
        case let .alreadyInCatalogue(name):
            refusal = "\(name) is already offered in every Open in menu when it is installed."
        case .alreadyAdded:
            refusal = "\(app.name) has already been added."
        case nil:
            break
        }
        reload()
    }

    private func remove(_ app: ExternalApp) {
        refusal = nil
        OpenInCustomApps().remove(bundleID: app.bundleID)
        reload()
    }

    private func load() {
        apps = OpenInCustomApps().apps
        let found = apps.compactMap { app in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID).map { (app.bundleID, $0) }
        }
        locations = Dictionary(found, uniquingKeysWith: { first, _ in first })
    }

    private func reload() {
        load()
        InstalledApps.invalidate()
    }
}
