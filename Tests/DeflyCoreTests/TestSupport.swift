import Foundation
@testable import DeflyCore

enum TestApps {
    static let safari = HandlerApplication(
        applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari",
        compatibility: .systemCandidate
    )

    static let arc = HandlerApplication(
        applicationURL: URL(fileURLWithPath: "/Applications/Arc.app"),
        bundleIdentifier: "company.thebrowser.Browser",
        displayName: "Arc",
        compatibility: .systemCandidate
    )
}

enum TestError: Error {
    case denied
}

@MainActor
final class FakeWorkspaceClient: WorkspaceClient {
    var defaults: [AssociationID: HandlerApplication] = [:]
    var candidates: [AssociationID: [HandlerApplication]] = [:]
    var setErrors: [AssociationID: Error] = [:]
    var events: [String] = []

    func defaultApplication(
        for association: AssociationID
    ) -> HandlerApplication? {
        events.append("read:\(association.stableKey)")
        return defaults[association]
    }

    func candidateApplications(
        for association: AssociationID
    ) -> [HandlerApplication] {
        candidates[association] ?? []
    }

    func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        events.append("set:\(association.stableKey)")
        if let error = setErrors[association] {
            throw error
        }

        defaults[association] = application
    }
}
