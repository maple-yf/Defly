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
        }
        .tint(.blue)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection {
        case .overview:
            OverviewView(
                workspace: container.workspace,
                catalog: container.catalog,
                preferences: container.preferencesStore
            )
        case .fileTypes, .urlSchemes, .applications, .settings:
            PlaceholderDestinationView(destination: selection)
        }
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
