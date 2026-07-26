import DeflyCore
import Foundation

@MainActor
final class FixtureWorkspaceClient: WorkspaceClient {
    private var defaults: [AssociationID: HandlerApplication]
    private let candidates: [HandlerApplication]
    private var failOnce: Set<AssociationID>
    let installedApplications: [InstalledApplication]

    init(arguments: [String] = []) {
        let safari = HandlerApplication(
            applicationURL: URL(
                fileURLWithPath: "/Applications/Safari.app"
            ),
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            compatibility: .systemCandidate
        )
        let preview = HandlerApplication(
            applicationURL: URL(
                fileURLWithPath: "/System/Applications/Preview.app"
            ),
            bundleIdentifier: "com.apple.Preview",
            displayName: "Preview",
            compatibility: .systemCandidate
        )
        let arc = HandlerApplication(
            applicationURL: URL(
                fileURLWithPath: "/Applications/Arc.app"
            ),
            bundleIdentifier: "company.thebrowser.Browser",
            displayName: "Arc",
            compatibility: .systemCandidate
        )

        candidates = [safari, preview, arc]
        failOnce = arguments.contains("-fixture-partial-failure")
            ? [.urlScheme("http")]
            : []
        installedApplications = [
            InstalledApplication(
                url: safari.applicationURL,
                bundleIdentifier: safari.bundleIdentifier,
                displayName: safari.displayName,
                declaredAssociations: [
                    .urlScheme("http"),
                    .urlScheme("https"),
                    .contentType("public.html")
                ]
            ),
            InstalledApplication(
                url: preview.applicationURL,
                bundleIdentifier: preview.bundleIdentifier,
                displayName: preview.displayName,
                declaredAssociations: [
                    .contentType("com.adobe.pdf"),
                    .contentType("public.png"),
                    .contentType("public.jpeg"),
                    .contentType("public.heic"),
                    .contentType("com.compuserve.gif"),
                    .contentType("public.tiff")
                ]
            ),
            InstalledApplication(
                url: arc.applicationURL,
                bundleIdentifier: arc.bundleIdentifier,
                displayName: arc.displayName,
                declaredAssociations: [
                    .urlScheme("http"),
                    .urlScheme("https"),
                    .contentType("public.html")
                ]
            )
        ]
        defaults = Dictionary(
            uniqueKeysWithValues:
                BuiltInAssociationCatalog.descriptors.map {
                    (
                        $0.association,
                        $0.category == .web ? safari : preview
                    )
                }
        )
    }

    func defaultApplication(
        for association: AssociationID
    ) -> HandlerApplication? {
        defaults[association]
    }

    func candidateApplications(
        for association: AssociationID
    ) -> [HandlerApplication] {
        candidates
    }

    func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        if failOnce.remove(association) != nil {
            throw FixtureWorkspaceError.simulatedUserDenial
        }
        defaults[association] = application
    }
}

private enum FixtureWorkspaceError: LocalizedError {
    case simulatedUserDenial

    var errorDescription: String? {
        "Simulated macOS consent denial"
    }
}
