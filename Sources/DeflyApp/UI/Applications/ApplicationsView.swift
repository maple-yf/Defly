import DeflyCore
import SwiftUI

@MainActor
private final class ApplicationsViewModel: ObservableObject {
    @Published private(set) var applications: [InstalledApplication] = []
    @Published private(set) var isLoading = false
    @Published var searchText = ""

    private let workspace: any WorkspaceClient
    private let applicationLoader:
        @MainActor () async -> [InstalledApplication]

    init(
        workspace: any WorkspaceClient,
        applicationLoader: @escaping
            @MainActor () async -> [InstalledApplication]
    ) {
        self.workspace = workspace
        self.applicationLoader = applicationLoader
    }

    func load() async {
        guard applications.isEmpty, !isLoading else {
            return
        }

        isLoading = true
        applications = await applicationLoader()
        isLoading = false
    }

    var filteredApplications: [InstalledApplication] {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else {
            return applications
        }

        return applications.filter { application in
            application.displayName.localizedCaseInsensitiveContains(
                query
            )
                || application.bundleIdentifier?
                    .localizedCaseInsensitiveContains(query) == true
        }
    }

    func application(id: String?) -> InstalledApplication? {
        guard let id else {
            return nil
        }
        return filteredApplications.first { $0.id == id }
    }

    func isAssigned(
        _ association: AssociationID,
        to application: InstalledApplication
    ) -> Bool {
        guard let handler = workspace.defaultApplication(
            for: association
        ) else {
            return false
        }

        if let bundleIdentifier = application.bundleIdentifier {
            return handler.bundleIdentifier == bundleIdentifier
        }
        return handler.applicationURL.standardizedFileURL
            == application.url.standardizedFileURL
    }
}

struct ApplicationsView: View {
    @StateObject private var viewModel: ApplicationsViewModel
    @State private var selectedApplicationID: String?
    @State private var selectedAssociations: Set<AssociationID> = []

    private let catalog: AssociationCatalog
    private let onRequestChanges:
        ([AssociationID], HandlerApplication) -> Void

    init(
        workspace: any WorkspaceClient,
        catalog: AssociationCatalog,
        applicationLoader: @escaping
            @MainActor () async -> [InstalledApplication],
        onRequestChanges: @escaping
            ([AssociationID], HandlerApplication) -> Void = {
                _,
                _ in
            }
    ) {
        _viewModel = StateObject(
            wrappedValue: ApplicationsViewModel(
                workspace: workspace,
                applicationLoader: applicationLoader
            )
        )
        self.catalog = catalog
        self.onRequestChanges = onRequestChanges
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                applicationList
                inspector
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(Text("nav.applications"))
        .task {
            await viewModel.load()
            selectFirstAvailable()
        }
        .onChange(of: viewModel.searchText) {
            selectFirstAvailable()
        }
        .onChange(of: selectedApplicationID) {
            selectedAssociations.removeAll()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("nav.applications")
                    .font(.system(size: 28, weight: .bold))
                Text("applications.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(
                        Text("applications.loading")
                    )
            }

            Button {
                reviewSelectedAssociations()
            } label: {
                Label(
                    "applications.reviewSelection",
                    systemImage: "checklist"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedAssociations.isEmpty)
            .accessibilityIdentifier(
                "applications.reviewSelection"
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var applicationList: some View {
        List(
            viewModel.filteredApplications,
            selection: $selectedApplicationID
        ) { application in
            HStack(spacing: 11) {
                ApplicationIconView(
                    installedApplication: application,
                    size: 34
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(application.displayName)
                        .lineLimit(1)
                    Text(
                        application.bundleIdentifier
                            ?? application.url.lastPathComponent
                    )
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(.vertical, 3)
            .tag(application.id)
            .accessibilityIdentifier(
                "applications.row.\(application.id)"
            )
        }
        .listStyle(.inset)
        .searchable(
            text: $viewModel.searchText,
            prompt: Text("applications.searchPrompt")
        )
        .overlay {
            if !viewModel.isLoading
                && viewModel.filteredApplications.isEmpty {
                ContentUnavailableView.search(
                    text: viewModel.searchText
                )
            }
        }
        .frame(
            minWidth: 280,
            idealWidth: 320,
            maxWidth: 390
        )
    }

    @ViewBuilder
    private var inspector: some View {
        if let application = viewModel.application(
            id: selectedApplicationID
        ) {
            ApplicationInspector(
                application: application,
                contentTypes: associations(
                    for: application,
                    kind: .contentTypes
                ),
                urlSchemes: associations(
                    for: application,
                    kind: .urlSchemes
                ),
                selectedAssociations: $selectedAssociations,
                isAssigned: { association in
                    viewModel.isAssigned(
                        association,
                        to: application
                    )
                }
            )
            .id(application.id)
        } else if viewModel.isLoading {
            ProgressView("applications.loading")
                .frame(
                    minWidth: 430,
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
        } else {
            ContentUnavailableView(
                "applications.noSelection",
                systemImage: "app.dashed",
                description: Text(
                    "applications.noSelection.description"
                )
            )
            .frame(
                minWidth: 430,
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }

    private func selectFirstAvailable() {
        let applications = viewModel.filteredApplications
        if let selectedApplicationID,
           applications.contains(
               where: { $0.id == selectedApplicationID }
           ) {
            return
        }
        selectedApplicationID = applications.first?.id
    }

    private func associations(
        for application: InstalledApplication,
        kind: ExplorerMode
    ) -> [AssociationPresentation] {
        let descriptors = Dictionary(
            catalog.snapshot().map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        return application.declaredAssociations
            .filter { association in
                switch (kind, association) {
                case (.contentTypes, .contentType):
                    true
                case (.urlSchemes, .urlScheme):
                    true
                default:
                    false
                }
            }
            .map { association in
                AssociationPresentation(
                    association: association,
                    descriptor: descriptors[
                        association.stableKey
                    ]
                )
            }
            .sorted { $0.identifier < $1.identifier }
    }

    private func reviewSelectedAssociations() {
        guard let application = viewModel.application(
            id: selectedApplicationID
        ) else {
            return
        }

        let handler = HandlerApplication(
            applicationURL: application.url,
            bundleIdentifier: application.bundleIdentifier,
            displayName: application.displayName,
            compatibility: .manuallySelected
        )
        onRequestChanges(
            selectedAssociations.sorted {
                $0.stableKey < $1.stableKey
            },
            handler
        )
    }
}

private struct AssociationPresentation: Identifiable {
    let association: AssociationID
    let descriptor: AssociationDescriptor?

    var id: String {
        association.stableKey
    }

    var identifier: String {
        switch association {
        case .contentType(let identifier):
            identifier
        case .urlScheme(let scheme):
            scheme
        }
    }

    var localizationKey: String {
        descriptor?.localizationKey ?? identifier
    }
}

private struct ApplicationInspector: View {
    let application: InstalledApplication
    let contentTypes: [AssociationPresentation]
    let urlSchemes: [AssociationPresentation]
    @Binding var selectedAssociations: Set<AssociationID>
    let isAssigned: (AssociationID) -> Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                applicationHeader
                declaredAssociationsCard
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 430,
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var applicationHeader: some View {
        HStack(spacing: 16) {
            ApplicationIconView(
                installedApplication: application,
                size: 64
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(application.displayName)
                    .font(.system(size: 26, weight: .bold))

                Group {
                    if let bundleIdentifier =
                        application.bundleIdentifier {
                        Text(bundleIdentifier)
                    } else {
                        Text(
                            "applications.missingBundleIdentifier"
                        )
                    }
                }
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

                Text(application.url.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
        }
    }

    private var declaredAssociationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("applications.declaredAssociations")
                    .font(.headline)

                if contentTypes.isEmpty && urlSchemes.isEmpty {
                    Label(
                        "applications.noDeclaredAssociations",
                        systemImage: "doc.badge.ellipsis"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    associationGroup(
                        titleKey: "applications.contentTypes",
                        associations: contentTypes
                    )
                    associationGroup(
                        titleKey: "applications.urlSchemes",
                        associations: urlSchemes
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func associationGroup(
        titleKey: String,
        associations: [AssociationPresentation]
    ) -> some View {
        if !associations.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text(LocalizedStringKey(titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(associations) { presentation in
                    Toggle(
                        isOn: selectionBinding(
                            for: presentation.association
                        )
                    ) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    LocalizedStringKey(
                                        presentation.localizationKey
                                    )
                                )
                                Text(presentation.identifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 10)

                            if isAssigned(presentation.association) {
                                Label(
                                    "applications.currentlyAssigned",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    .toggleStyle(.checkbox)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func selectionBinding(
        for association: AssociationID
    ) -> Binding<Bool> {
        Binding(
            get: {
                selectedAssociations.contains(association)
            },
            set: { isSelected in
                if isSelected {
                    selectedAssociations.insert(association)
                } else {
                    selectedAssociations.remove(association)
                }
            }
        )
    }
}
