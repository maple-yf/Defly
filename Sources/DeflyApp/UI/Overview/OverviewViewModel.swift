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

        if !requestedKeys.isEmpty {
            return requestedKeys.compactMap { key in
                descriptors.first { $0.id == key }
            }
            .map(makeDescriptorAssignment)
        }

        let defaults = [
            "type:com.adobe.pdf",
            "type:net.daringfireball.markdown"
        ]
        var assignments = defaults.compactMap { key in
            descriptors.first { $0.id == key }
        }
        .map(makeDescriptorAssignment)

        if let images = BuiltInAssociationCatalog.smartGroups.first(
            where: { $0.id == "commonImages" }
        ) {
            assignments.append(
                makeAssignment(
                    id: "smart:\(images.id)",
                    titleKey: images.localizationKey,
                    symbolName: "photo.on.rectangle.angled",
                    associations: images.associations
                )
            )
        }

        return assignments
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
            handlerState: handlerState
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
}
