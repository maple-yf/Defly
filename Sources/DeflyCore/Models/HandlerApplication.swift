import Foundation

public struct HandlerApplication: Hashable, Sendable, Identifiable {
    public enum Compatibility: String, Hashable, Sendable {
        case systemCandidate
        case manuallySelected
    }

    public let applicationURL: URL
    public let bundleIdentifier: String?
    public let displayName: String
    public let compatibility: Compatibility

    public init(
        applicationURL: URL,
        bundleIdentifier: String?,
        displayName: String,
        compatibility: Compatibility
    ) {
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.compatibility = compatibility
    }

    public var stableID: String {
        bundleIdentifier.map { "bundle:\($0)" }
            ?? "url:\(applicationURL.standardizedFileURL.path)"
    }

    public var id: String {
        stableID
    }
}
