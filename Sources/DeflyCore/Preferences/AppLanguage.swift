import Foundation

public enum AppLanguage:
    String,
    CaseIterable,
    Codable,
    Identifiable,
    Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    public var id: String {
        rawValue
    }

    public var localizationKey: String {
        switch self {
        case .simplifiedChinese:
            "language.zhHans"
        case .english:
            "language.en"
        }
    }
}
