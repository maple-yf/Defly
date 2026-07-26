import XCTest
@testable import DeflyCore

final class BuiltInAssociationCatalogTests: XCTestCase {
    func testBrowserGroupContainsThreeAtomicAssociations() {
        let browser = BuiltInAssociationCatalog.smartGroups.first {
            $0.id == "browser"
        }

        XCTAssertEqual(browser?.associations.map(\.stableKey), [
            "scheme:http",
            "scheme:https",
            "type:public.html"
        ])
    }

    func testCatalogDeduplicatesStableKeys() {
        let source = BuiltInAssociationCatalog.descriptors
            + [BuiltInAssociationCatalog.descriptors[0]]
        let catalog = AssociationCatalog(seed: source)

        XCTAssertEqual(
            Set(catalog.snapshot().map(\.id)).count,
            catalog.snapshot().count
        )
    }
}
