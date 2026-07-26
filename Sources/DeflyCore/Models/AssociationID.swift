import Foundation

public enum AssociationID: Hashable, Codable, Sendable {
    case contentType(String)
    case urlScheme(String)

    public enum ValidationError: Error, Equatable {
        case emptyIdentifier
    }

    public static func makeContentType(_ rawValue: String) throws -> Self {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw ValidationError.emptyIdentifier
        }

        return .contentType(value)
    }

    public static func makeURLScheme(_ rawValue: String) throws -> Self {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty else {
            throw ValidationError.emptyIdentifier
        }

        return .urlScheme(value)
    }

    public var stableKey: String {
        switch self {
        case .contentType(let identifier):
            "type:\(identifier)"
        case .urlScheme(let scheme):
            "scheme:\(scheme)"
        }
    }

    public var representativeURL: URL? {
        guard case .urlScheme(let scheme) = self else {
            return nil
        }

        return URL(string: "\(scheme):")
    }
}
