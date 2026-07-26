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

public struct ChangeItemResult: Sendable, Identifiable {
    public enum Status: String, Hashable, Sendable {
        case verified
        case failed
        case notApplied
    }

    public let change: PlannedChange
    public let status: Status
    public let errorDescription: String?

    public init(
        change: PlannedChange,
        status: Status,
        errorDescription: String?
    ) {
        self.change = change
        self.status = status
        self.errorDescription = errorDescription
    }

    public var id: String {
        change.id
    }
}

public struct ChangeReport: Sendable {
    public let sourcePlan: ChangePlan
    public let results: [ChangeItemResult]

    public init(
        sourcePlan: ChangePlan,
        results: [ChangeItemResult]
    ) {
        self.sourcePlan = sourcePlan
        self.results = results
    }

    public func retryPlan() -> ChangePlan {
        ChangePlan(
            changes: results
                .filter { $0.status != .verified }
                .map(\.change)
        )
    }
}
