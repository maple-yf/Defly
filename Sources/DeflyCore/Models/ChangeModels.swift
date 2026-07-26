import Foundation

public struct PlannedChange: Hashable, Sendable, Identifiable {
    public enum Compatibility: String, Hashable, Sendable {
        case systemCandidate
        case manuallySelected
    }

    public let association: AssociationID
    public let previousHandler: HandlerApplication?
    public let targetHandler: HandlerApplication
    public let compatibility: Compatibility

    public init(
        association: AssociationID,
        previousHandler: HandlerApplication?,
        targetHandler: HandlerApplication,
        compatibility: Compatibility
    ) {
        self.association = association
        self.previousHandler = previousHandler
        self.targetHandler = targetHandler
        self.compatibility = compatibility
    }

    public var id: String {
        association.stableKey
    }
}

public struct ChangePlan: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let changes: [PlannedChange]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        changes: [PlannedChange]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.changes = changes
    }
}
