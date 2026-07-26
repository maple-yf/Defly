import Foundation

@MainActor
public protocol WorkspaceClient: AnyObject {
    func defaultApplication(for association: AssociationID) -> HandlerApplication?
    func candidateApplications(for association: AssociationID) -> [HandlerApplication]
    func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws
}
