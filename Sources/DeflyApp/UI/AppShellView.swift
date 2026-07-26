import DeflyCore
import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case overview
    case fileTypes
    case urlSchemes
    case applications
    case settings

    var id: String {
        rawValue
    }

    var localizationKey: String {
        switch self {
        case .overview:
            "nav.overview"
        case .fileTypes:
            "nav.fileTypes"
        case .urlSchemes:
            "nav.urlSchemes"
        case .applications:
            "nav.applications"
        case .settings:
            "nav.settings"
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            "rectangle.grid.2x2"
        case .fileTypes:
            "doc"
        case .urlSchemes:
            "link"
        case .applications:
            "app.dashed"
        case .settings:
            "gearshape"
        }
    }
}

struct AppShellView: View {
    @ObservedObject var container: AppContainer
    @State private var selection = SidebarDestination.overview
    @State private var pendingPlan: ChangePlan?
    @State private var refreshID = UUID()
    @State private var showsNoChangesAlert = false

    var body: some View {
        NavigationSplitView {
            List(
                SidebarDestination.allCases,
                selection: $selection
            ) { destination in
                Label {
                    Text(
                        LocalizedStringKey(
                            destination.localizationKey
                        )
                    )
                } icon: {
                    Image(systemName: destination.symbolName)
                }
                .tag(destination)
                .accessibilityIdentifier(
                    "sidebar.\(destination.rawValue)"
                )
            }
            .navigationSplitViewColumnWidth(
                min: 190,
                ideal: 220,
                max: 260
            )
        } detail: {
            destinationView
                .id(refreshID)
        }
        .tint(.blue)
        .sheet(item: $pendingPlan) { plan in
            ChangeConfirmationSheet(
                plan: plan,
                executor: ChangeExecutor(
                    workspace: container.workspace
                ),
                catalog: container.catalog,
                onRefresh: {
                    refreshID = UUID()
                }
            )
        }
        .alert(
            "change.noChanges.title",
            isPresented: $showsNoChangesAlert
        ) {
            Button("change.complete", role: .cancel) {}
        } message: {
            Text("change.noChanges.message")
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
        case .overview:
            OverviewView(
                workspace: container.workspace,
                catalog: container.catalog,
                preferences: container.preferencesStore,
                onRequestChanges: requestChanges
            )
        case .fileTypes:
            ExplorerView(
                mode: .contentTypes,
                catalog: container.catalog,
                workspace: container.workspace,
                preferences: container.preferencesStore,
                applicationLoader: {
                    await container.applications()
                },
                onRequestChange: { descriptor, application in
                    requestChanges(
                        [descriptor.association],
                        application
                    )
                }
            )
        case .urlSchemes:
            ExplorerView(
                mode: .urlSchemes,
                catalog: container.catalog,
                workspace: container.workspace,
                preferences: container.preferencesStore,
                applicationLoader: {
                    await container.applications()
                },
                onRequestChange: { descriptor, application in
                    requestChanges(
                        [descriptor.association],
                        application
                    )
                }
            )
        case .applications:
            ApplicationsView(
                workspace: container.workspace,
                catalog: container.catalog,
                applicationLoader: {
                    await container.applications()
                },
                onRequestChanges: requestChanges
            )
        case .settings:
            PlaceholderDestinationView(destination: selection)
        }
    }

    private func requestChanges(
        _ associations: [AssociationID],
        _ application: HandlerApplication
    ) {
        let plan = ChangePlanner(
            workspace: container.workspace
        )
        .makePlan(
            associations: associations,
            target: application
        )

        guard !plan.changes.isEmpty else {
            showsNoChangesAlert = true
            return
        }
        pendingPlan = plan
    }
}

private struct PlaceholderDestinationView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: destination.symbolName)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(destination.localizationKey))
                .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(
            Text(LocalizedStringKey(destination.localizationKey))
        )
    }
}
