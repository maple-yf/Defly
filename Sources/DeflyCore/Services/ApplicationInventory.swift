import Foundation

public struct InstalledApplication: Hashable, Sendable, Identifiable {
    public let url: URL
    public let bundleIdentifier: String?
    public let displayName: String
    public let declaredAssociations: Set<AssociationID>

    public init(
        url: URL,
        bundleIdentifier: String?,
        displayName: String,
        declaredAssociations: Set<AssociationID>
    ) {
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.declaredAssociations = declaredAssociations
    }

    public var id: String {
        bundleIdentifier ?? url.standardizedFileURL.path
    }
}

@MainActor
public final class ApplicationInventory: NSObject {
    private var activeQuery: NSMetadataQuery?
    private var continuation:
        CheckedContinuation<[InstalledApplication], Never>?

    public func applications() async -> [InstalledApplication] {
        guard activeQuery == nil else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let query = NSMetadataQuery()
            query.searchScopes = [NSMetadataQueryLocalComputerScope]
            query.predicate = NSPredicate(
                format: "%K == %@",
                NSMetadataItemContentTypeKey,
                "com.apple.application-bundle"
            )
            self.activeQuery = query
            self.continuation = continuation
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(queryDidFinish(_:)),
                name: .NSMetadataQueryDidFinishGathering,
                object: query
            )
            query.start()
        }
    }

    @objc private func queryDidFinish(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else {
            return
        }

        query.disableUpdates()
        let applications = query.results
            .compactMap {
                ($0 as? NSMetadataItem)?
                    .value(forAttribute: NSMetadataItemURLKey) as? URL
            }
            .compactMap(makeApplication(at:))
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
        query.stop()
        NotificationCenter.default.removeObserver(
            self,
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        activeQuery = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: applications)
    }

    private func makeApplication(at url: URL) -> InstalledApplication? {
        guard let bundle = Bundle(url: url) else {
            return nil
        }

        return InstalledApplication(
            url: url,
            bundleIdentifier: bundle.bundleIdentifier,
            displayName: FileManager.default.displayName(atPath: url.path),
            declaredAssociations: declaredAssociations(
                in: bundle.infoDictionary ?? [:]
            )
        )
    }

    private func declaredAssociations(
        in info: [String: Any]
    ) -> Set<AssociationID> {
        var result: Set<AssociationID> = []

        let documentTypes =
            info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        documentTypes
            .flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
            .forEach { result.insert(.contentType($0)) }

        for key in [
            "UTImportedTypeDeclarations",
            "UTExportedTypeDeclarations"
        ] {
            let declarations = info[key] as? [[String: Any]] ?? []
            declarations
                .compactMap { $0["UTTypeIdentifier"] as? String }
                .forEach { result.insert(.contentType($0)) }
        }

        let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        urlTypes
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
            .map { $0.lowercased() }
            .forEach { result.insert(.urlScheme($0)) }

        return result
    }
}
