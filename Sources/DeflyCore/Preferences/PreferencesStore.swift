import Foundation

public struct PreferencesStore {
    public static let defaultPinnedAssociationKeys = [
        "type:com.adobe.pdf",
        "type:net.daringfireball.markdown",
        "smart:commonImages"
    ]

    private enum Key {
        static let language = "app.language"
        static let pinnedAssociations = "overview.pinnedAssociations"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var language: AppLanguage {
        get {
            defaults.string(forKey: Key.language)
                .flatMap(AppLanguage.init(rawValue:))
                ?? .simplifiedChinese
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.language)
        }
    }

    public var pinnedAssociationKeys: [String] {
        get {
            guard defaults.object(
                forKey: Key.pinnedAssociations
            ) != nil else {
                return Self.defaultPinnedAssociationKeys
            }
            return defaults.stringArray(
                forKey: Key.pinnedAssociations
            ) ?? []
        }
        set {
            defaults.set(newValue, forKey: Key.pinnedAssociations)
        }
    }
}
