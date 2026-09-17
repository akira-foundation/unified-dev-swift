import SwiftUI
import Observation
import Core

enum ProjectSetupSurface: Sendable, Equatable {
    case main
    case settings
}

@MainActor
@Observable
final class ProjectSetup {
    static let shared = ProjectSetup()

    struct Request: Identifiable, Equatable {
        let id = UUID()
        var path: String
        var contents: FolderContents
        var surface: ProjectSetupSurface
        var identityProblem: String?

        var folderName: String { (path as NSString).lastPathComponent }

        static func == (lhs: Request, rhs: Request) -> Bool { lhs.id == rhs.id }
    }

    var request: Request?

    @ObservationIgnored var onReady: ((String) async -> Void)?

    func present(_ request: Request) {
        self.request = request
    }

    func dismiss() {
        request = nil
    }

    func isPresenting(_ surface: ProjectSetupSurface) -> Bool {
        request?.surface == surface
    }

    static var capturedChoice: String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--project-setup-choice"),
              index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}

extension Binding where Value == ProjectSetup.Request? {
    func on(_ surface: ProjectSetupSurface) -> Binding<ProjectSetup.Request?> {
        Binding(
            get: { wrappedValue?.surface == surface ? wrappedValue : nil },
            set: { updated in
                guard wrappedValue?.surface == surface else { return }
                wrappedValue = updated
            }
        )
    }
}

extension Notification.Name {
    static let unifieddevOfferProjectSetup = Notification.Name("unifieddevOfferProjectSetup")
}
