import Foundation

public struct AssociationCatalog: Sendable {
    private let descriptorsByID: [String: AssociationDescriptor]

    public init(seed: [AssociationDescriptor]) {
        descriptorsByID = Dictionary(
            seed.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
    }

    public func snapshot() -> [AssociationDescriptor] {
        descriptorsByID.values.sorted { $0.id < $1.id }
    }
}
