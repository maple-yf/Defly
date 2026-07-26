import DeflyCore
import Foundation
import UniformTypeIdentifiers

enum ExplorerMode: Sendable {
    case contentTypes
    case urlSchemes

    var titleKey: String {
        switch self {
        case .contentTypes:
            "nav.fileTypes"
        case .urlSchemes:
            "nav.urlSchemes"
        }
    }

    var subtitleKey: String {
        switch self {
        case .contentTypes:
            "explorer.fileTypes.subtitle"
        case .urlSchemes:
            "explorer.urlSchemes.subtitle"
        }
    }
}

enum ExplorerFilter: String, CaseIterable, Identifiable {
    case all
    case common
    case pinned
    case unassigned

    var id: String {
        rawValue
    }

    var localizationKey: String {
        "explorer.filter.\(rawValue)"
    }
}

@MainActor
final class ExplorerViewModel: ObservableObject {
    struct CategoryGroup: Identifiable {
        let category: AssociationDescriptor.Category
        let descriptors: [AssociationDescriptor]

        var id: String {
            category.rawValue
        }
    }

    @Published var searchText = ""
    @Published var filter = ExplorerFilter.all
    @Published private(set) var isDiscovering = false

    let mode: ExplorerMode

    private let catalog: AssociationCatalog
    private let workspace: any WorkspaceClient
    private let preferences: PreferencesStore
    private let applicationLoader:
        @MainActor () async -> [InstalledApplication]
    private var discoveredDescriptors: [AssociationDescriptor] = []

    init(
        mode: ExplorerMode,
        catalog: AssociationCatalog,
        workspace: any WorkspaceClient,
        preferences: PreferencesStore,
        applicationLoader: @escaping
            @MainActor () async -> [InstalledApplication]
    ) {
        self.mode = mode
        self.catalog = catalog
        self.workspace = workspace
        self.preferences = preferences
        self.applicationLoader = applicationLoader
    }

    func discoverDeclaredAssociations() async {
        guard discoveredDescriptors.isEmpty else {
            return
        }

        isDiscovering = true
        let applications = await applicationLoader()
        discoveredDescriptors = makeDiscoveredDescriptors(
            applications: applications
        )
        isDiscovering = false
    }

    func groups(locale: Locale) -> [CategoryGroup] {
        let grouped = Dictionary(
            grouping: filteredDescriptors(locale: locale),
            by: \.category
        )

        return AssociationDescriptor.Category.allCases.compactMap {
            category in
            guard let descriptors = grouped[category],
                  !descriptors.isEmpty else {
                return nil
            }
            return CategoryGroup(
                category: category,
                descriptors: descriptors
            )
        }
    }

    func filteredDescriptors(
        locale: Locale
    ) -> [AssociationDescriptor] {
        descriptorsForMode()
            .filter(matchesSelectedFilter)
            .filter { descriptor in
                matchesSearch(descriptor, locale: locale)
            }
            .sorted { left, right in
                let leftName = localizedName(
                    for: left,
                    locale: locale
                )
                let rightName = localizedName(
                    for: right,
                    locale: locale
                )
                return leftName.localizedStandardCompare(rightName)
                    == .orderedAscending
            }
    }

    func descriptor(
        id: String?,
        locale: Locale
    ) -> AssociationDescriptor? {
        guard let id else {
            return nil
        }
        return filteredDescriptors(locale: locale)
            .first { $0.id == id }
    }

    func currentApplication(
        for descriptor: AssociationDescriptor
    ) -> HandlerApplication? {
        workspace.defaultApplication(
            for: descriptor.association
        )
    }

    func candidates(
        for descriptor: AssociationDescriptor
    ) -> [HandlerApplication] {
        workspace.candidateApplications(
            for: descriptor.association
        )
        .reduce(into: [String: HandlerApplication]()) {
            result,
            application in
            result[application.stableID] = application
        }
        .values
        .sorted {
            $0.displayName.localizedStandardCompare($1.displayName)
                == .orderedAscending
        }
    }

    func localizedName(
        for descriptor: AssociationDescriptor,
        locale: Locale
    ) -> String {
        LocalizedText.string(
            descriptor.localizationKey,
            locale: locale
        )
    }

    private func descriptorsForMode() -> [AssociationDescriptor] {
        let known = catalog.snapshot() + discoveredDescriptors
        let unique = Dictionary(
            known.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        return unique.values.filter { descriptor in
            switch (mode, descriptor.association) {
            case (.contentTypes, .contentType):
                true
            case (.urlSchemes, .urlScheme):
                true
            default:
                false
            }
        }
    }

    private func matchesSelectedFilter(
        _ descriptor: AssociationDescriptor
    ) -> Bool {
        switch filter {
        case .all:
            true
        case .common:
            commonAssociationKeys.contains(descriptor.id)
        case .pinned:
            preferences.pinnedAssociationKeys.contains(descriptor.id)
        case .unassigned:
            workspace.defaultApplication(
                for: descriptor.association
            ) == nil
        }
    }

    private func matchesSearch(
        _ descriptor: AssociationDescriptor,
        locale: Locale
    ) -> Bool {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else {
            return true
        }

        let candidates = [
            localizedName(for: descriptor, locale: locale),
            descriptor.localizationKey,
            descriptor.id,
            associationValue(descriptor.association)
        ]
            + descriptor.filenameExtensions
            + descriptor.mimeTypes
            + workspace
                .candidateApplications(
                    for: descriptor.association
                )
                .map(\.displayName)

        return candidates.contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    private var commonAssociationKeys: Set<String> {
        Set(
            BuiltInAssociationCatalog.smartGroups
                .flatMap(\.associations)
                .map(\.stableKey)
        )
    }

    private func associationValue(
        _ association: AssociationID
    ) -> String {
        switch association {
        case .contentType(let identifier):
            identifier
        case .urlScheme(let scheme):
            scheme
        }
    }

    private func makeDiscoveredDescriptors(
        applications: [InstalledApplication]
    ) -> [AssociationDescriptor] {
        let knownIDs = Set(catalog.snapshot().map(\.id))
        let associations = Set(
            applications.flatMap(\.declaredAssociations)
        )

        return associations
            .filter { !knownIDs.contains($0.stableKey) }
            .map(makeDescriptor)
    }

    private func makeDescriptor(
        association: AssociationID
    ) -> AssociationDescriptor {
        switch association {
        case .urlScheme(let scheme):
            return AssociationDescriptor(
                association: association,
                localizationKey: scheme,
                category: .web,
                filenameExtensions: [],
                mimeTypes: []
            )
        case .contentType(let identifier):
            let type = UTType(identifier)
            return AssociationDescriptor(
                association: association,
                localizationKey:
                    type?.localizedDescription ?? identifier,
                category: category(for: type),
                filenameExtensions:
                    type?.preferredFilenameExtension.map { [$0] }
                    ?? [],
                mimeTypes:
                    type?.preferredMIMEType.map { [$0] } ?? []
            )
        }
    }

    private func category(
        for type: UTType?
    ) -> AssociationDescriptor.Category {
        guard let type else {
            return .document
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .audio)
            || type.conforms(to: .movie) {
            return .media
        }
        if type.conforms(to: .archive) {
            return .archive
        }
        if type.conforms(to: .sourceCode)
            || type.conforms(to: .plainText) {
            return .development
        }
        return .document
    }
}
