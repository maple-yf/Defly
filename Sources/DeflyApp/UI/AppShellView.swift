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
            VStack(spacing: 0) {
                sidebarBrand

                Divider()
                    .padding(.horizontal, 12)

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
                .listStyle(.sidebar)
            }
            .background(.thinMaterial)
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

    private var sidebarBrand: some View {
        HStack(spacing: 11) {
            DeflyIconView(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Defly")
                    .font(.headline)
                Text("brand.tagline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sidebar.brand")
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
            SettingsView(
                container: container,
                catalog: container.catalog
            )
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
