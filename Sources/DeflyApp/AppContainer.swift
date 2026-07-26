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
            workspace = FixtureWorkspaceClient(arguments: arguments)
        } else {
            workspace = SystemWorkspaceClient()
        }
    }

    var preferencesStore: PreferencesStore {
        preferences
    }

    func setLanguage(_ language: AppLanguage) {
        preferences.language = language
        self.language = language
    }
}
