import Foundation

public struct AssociationDescriptor: Hashable, Sendable, Identifiable {
    public enum Category: String, CaseIterable, Sendable {
        case web
        case communication
        case document
        case image
        case media
        case development
        case archive
    }

    public let association: AssociationID
    public let localizationKey: String
    public let category: Category
    public let filenameExtensions: [String]
    public let mimeTypes: [String]

    public init(
        association: AssociationID,
        localizationKey: String,
        category: Category,
        filenameExtensions: [String],
        mimeTypes: [String]
    ) {
        self.association = association
        self.localizationKey = localizationKey
        self.category = category
        self.filenameExtensions = filenameExtensions
        self.mimeTypes = mimeTypes
    }

    public var id: String {
        association.stableKey
    }
}

public struct SmartGroupDefinition: Hashable, Sendable, Identifiable {
    public let id: String
    public let localizationKey: String
    public let associations: [AssociationID]

    public init(
        id: String,
        localizationKey: String,
        associations: [AssociationID]
    ) {
        self.id = id
        self.localizationKey = localizationKey
        self.associations = associations
    }
}
