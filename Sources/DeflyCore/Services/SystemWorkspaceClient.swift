import AppKit
import UniformTypeIdentifiers

@MainActor
public final class SystemWorkspaceClient: WorkspaceClient {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func defaultApplication(
        for association: AssociationID
    ) -> HandlerApplication? {
        let url: URL?
        switch association {
        case .contentType(let identifier):
            url = UTType(identifier).flatMap {
                workspace.urlForApplication(toOpen: $0)
            }
        case .urlScheme:
            url = association.representativeURL.flatMap {
                workspace.urlForApplication(toOpen: $0)
            }
        }

        return url.map {
            makeApplication(url: $0, compatibility: .systemCandidate)
        }
    }

    public func candidateApplications(
        for association: AssociationID
    ) -> [HandlerApplication] {
        let urls: [URL]
        switch association {
        case .contentType(let identifier):
            urls = UTType(identifier).map {
                workspace.urlsForApplications(toOpen: $0)
            } ?? []
        case .urlScheme:
            urls = association.representativeURL.map {
                workspace.urlsForApplications(toOpen: $0)
            } ?? []
        }

        return urls.map {
            makeApplication(url: $0, compatibility: .systemCandidate)
        }
    }

    public func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        switch association {
        case .contentType(let identifier):
            guard let type = UTType(identifier) else {
                throw WorkspaceError.unresolvableContentType(identifier)
            }
            try await workspace.setDefaultApplication(
                at: application.applicationURL,
                toOpen: type
            )
        case .urlScheme(let scheme):
            try await workspace.setDefaultApplication(
                at: application.applicationURL,
                toOpenURLsWithScheme: scheme
            )
        }
    }

    private func makeApplication(
        url: URL,
        compatibility: HandlerApplication.Compatibility
    ) -> HandlerApplication {
        let bundle = Bundle(url: url)
        return HandlerApplication(
            applicationURL: url,
            bundleIdentifier: bundle?.bundleIdentifier,
            displayName: FileManager.default.displayName(atPath: url.path),
            compatibility: compatibility
        )
    }
}

public enum WorkspaceError: Error, Equatable {
    case unresolvableContentType(String)
}
