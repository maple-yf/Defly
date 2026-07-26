import DeflyCore
import Foundation
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    @Published private(set) var language: AppLanguage

    let workspace: any WorkspaceClient
    let catalog: AssociationCatalog
    let applicationInventory: ApplicationInventory

    private var preferences: PreferencesStore
    private var cachedApplications: [InstalledApplication]?
    private var applicationsTask:
        Task<[InstalledApplication], Never>?
    private let fixtureApplications: [InstalledApplication]?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) {
        if arguments.contains("-reset-preferences") {
            defaults.removeObject(forKey: "app.language")
            defaults.removeObject(
                forKey: "overview.pinnedAssociations"
            )
        }

        let preferences = PreferencesStore(defaults: defaults)
        self.preferences = preferences
        language = preferences.language
        catalog = AssociationCatalog(
            seed: BuiltInAssociationCatalog.descriptors
        )
        applicationInventory = ApplicationInventory()

        if arguments.contains("-ui-testing")
            || arguments.contains("-use-fixtures") {
            let fixture = FixtureWorkspaceClient(
                arguments: arguments
            )
            workspace = fixture
            fixtureApplications = fixture.installedApplications
        } else {
            workspace = SystemWorkspaceClient()
            fixtureApplications = nil
        }
    }

    var preferencesStore: PreferencesStore {
        preferences
    }

    func setLanguage(_ language: AppLanguage) {
        preferences.language = language
        self.language = language
    }

    func applications() async -> [InstalledApplication] {
        if let fixtureApplications {
            return fixtureApplications
        }
        if let cachedApplications {
            return cachedApplications
        }
        if let applicationsTask {
            return await applicationsTask.value
        }

        let inventory = applicationInventory
        let task = Task { @MainActor in
            await inventory.applications()
        }
        applicationsTask = task
        let applications = await task.value
        cachedApplications = applications
        applicationsTask = nil
        return applications
    }
}
