import XCTest
@testable import DeflyCore

final class PreferencesStoreTests: XCTestCase {
    func testFreshStoreDefaultsToChinese() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.language, .simplifiedChinese)
    }

    func testLanguageAndPinsPersist() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        var store = PreferencesStore(defaults: defaults)
        store.language = .english
        store.pinnedAssociationKeys = ["type:com.adobe.pdf"]

        let restored = PreferencesStore(defaults: defaults)

        XCTAssertEqual(restored.language, .english)
        XCTAssertEqual(
            restored.pinnedAssociationKeys,
            ["type:com.adobe.pdf"]
        )
    }
}
