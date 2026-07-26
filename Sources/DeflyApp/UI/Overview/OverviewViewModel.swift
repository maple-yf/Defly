import DeflyCore
import Foundation
import SwiftUI

@MainActor
final class OverviewViewModel: ObservableObject {
    struct Assignment: Identifiable {
        enum HandlerState {
            case application(HandlerApplication)
            case mixed
            case notAssigned
        }

        let id: String
        let titleKey: String
        let symbolName: String
        let associations: [AssociationID]
        let tags: [String]
        let handlerState: HandlerState
        let candidates: [HandlerApplication]
    }

    @Published private(set) var commonGroups: [Assignment] = []
    @Published private(set) var pinned: [Assignment] = []
    @Published private(set) var isRefreshing = false

    private let workspace: any WorkspaceClient
    private let catalog: AssociationCatalog
    private let preferences: PreferencesStore

    init(
        workspace: any WorkspaceClient,
        catalog: AssociationCatalog,
        preferences: PreferencesStore
    ) {
        self.workspace = workspace
        self.catalog = catalog
        self.preferences = preferences
    }

    func refresh() {
        isRefreshing = true

        let smartGroups = BuiltInAssociationCatalog.smartGroups
        commonGroups = [
            smartGroups.first { $0.id == "browser" },
            smartGroups.first { $0.id == "email" }
        ]
        .compactMap { $0 }
        .map {
            makeAssignment(
                id: "smart:\($0.id)",
                titleKey: $0.localizationKey,
                symbolName: $0.id == "browser"
                    ? "safari"
                    : "envelope",
                associations: $0.associations
            )
        }

        pinned = makePinnedAssignments()
        isRefreshing = false
    }

    private func makePinnedAssignments() -> [Assignment] {
        let descriptors = catalog.snapshot()
        let requestedKeys = preferences.pinnedAssociationKeys

        return requestedKeys.compactMap { key in
            if let descriptor = descriptors.first(
                where: { $0.id == key }
            ) {
                return makeDescriptorAssignment(descriptor)
            }

            guard key.hasPrefix("smart:"),
                  let group =
                    BuiltInAssociationCatalog.smartGroups.first(
                        where: { "smart:\($0.id)" == key }
                    ) else {
                return nil
            }
            return makeAssignment(
                id: key,
                titleKey: group.localizationKey,
                symbolName: group.id == "commonImages"
                    ? "photo.on.rectangle.angled"
                    : group.id == "browser"
                        ? "safari"
                        : "envelope",
                associations: group.associations
            )
        }
    }

    private func makeDescriptorAssignment(
        _ descriptor: AssociationDescriptor
    ) -> Assignment {
        makeAssignment(
            id: descriptor.id,
            titleKey: descriptor.localizationKey,
            symbolName: symbolName(for: descriptor.category),
            associations: [descriptor.association]
        )
    }

    private func makeAssignment(
        id: String,
        titleKey: String,
        symbolName: String,
        associations: [AssociationID]
    ) -> Assignment {
        let handlers = associations.map {
            workspace.defaultApplication(for: $0)
        }
        let assignedHandlers = handlers.compactMap { $0 }
        let handlerState: Assignment.HandlerState

        if assignedHandlers.isEmpty {
            handlerState = .notAssigned
        } else if assignedHandlers.count == associations.count,
                  Set(assignedHandlers.map(\.stableID)).count == 1,
                  let handler = assignedHandlers.first {
            handlerState = .application(handler)
        } else {
            handlerState = .mixed
        }

        return Assignment(
            id: id,
            titleKey: titleKey,
            symbolName: symbolName,
            associations: associations,
            tags: makeTags(for: associations),
            handlerState: handlerState,
            candidates: compatibleCandidates(
                for: associations
            )
        )
    }

    private func makeTags(
        for associations: [AssociationID]
    ) -> [String] {
        let descriptorsByID = Dictionary(
            uniqueKeysWithValues: catalog.snapshot().map {
                ($0.association.stableKey, $0)
            }
        )

        return associations.map { association in
            switch association {
            case .urlScheme(let scheme):
                scheme
            case .contentType(let identifier):
                if let fileExtension = descriptorsByID[
                    association.stableKey
                ]?.filenameExtensions.first {
                    ".\(fileExtension)"
                } else {
                    identifier
                }
            }
        }
    }

    private func symbolName(
        for category: AssociationDescriptor.Category
    ) -> String {
        switch category {
        case .web:
            "globe"
        case .communication:
            "envelope"
        case .document:
            "doc.text"
        case .image:
            "photo"
        case .media:
            "play.rectangle"
        case .development:
            "chevron.left.forwardslash.chevron.right"
        case .archive:
            "archivebox"
        }
    }

    private func compatibleCandidates(
        for associations: [AssociationID]
    ) -> [HandlerApplication] {
        let candidateLists = associations.map {
            workspace.candidateApplications(for: $0)
        }
        guard let first = candidateLists.first else {
            return []
        }

        let commonIDs = candidateLists.dropFirst().reduce(
            Set(first.map(\.stableID))
        ) { result, applications in
            result.intersection(applications.map(\.stableID))
        }
        let candidatesByID = Dictionary(
            candidateLists
                .flatMap { $0 }
                .map { ($0.stableID, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        return commonIDs
            .compactMap { candidatesByID[$0] }
            .sorted {
                $0.displayName.localizedStandardCompare(
                    $1.displayName
                ) == .orderedAscending
            }
    }
}
