# Defly V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native, bilingual macOS app that reads and safely changes default handlers for UTTypes and URL schemes through Apple public APIs.

**Architecture:** Use an XcodeGen-generated macOS application target and a separate `DeflyCore` framework. `DeflyCore` owns domain models, catalogs, `NSWorkspace` access, planning, execution, and preferences; `DeflyApp` owns SwiftUI/AppKit presentation and dependency composition. All handler changes become explicit atomic plans, execute serially, and are verified by reading the system state back.

**Tech Stack:** Swift 6, SwiftUI, AppKit, UniformTypeIdentifiers, XCTest, XcodeGen, macOS 14+

## Global Constraints

- Minimum deployment target is exactly macOS 14.0; do not add macOS 12/13 compatibility branches.
- Use only Apple public APIs; never read or write the private LaunchServices database.
- Use no third-party runtime dependencies.
- Keep App Sandbox disabled and Hardened Runtime enabled.
- Use no helper, daemon, LaunchAgent, menu-bar process, telemetry, or network service.
- First launch language is `zh-Hans`; supported languages are `zh-Hans` and `en`.
- Use semantic system blue, SwiftUI/AppKit system materials, SF Symbols, and actual application icons.
- Every write requires a native confirmation sheet and post-write system verification.
- Multi-association changes are not transactions; preserve partial success and retry only failed items.
- Interface code must not leak into `DeflyCore`.

---

## File Map

```text
project.yml
Sources/
├── DeflyCore/
│   ├── Models/
│   │   ├── AssociationID.swift
│   │   ├── AssociationDescriptor.swift
│   │   ├── HandlerApplication.swift
│   │   └── ChangeModels.swift
│   ├── Catalog/
│   │   ├── BuiltInAssociationCatalog.swift
│   │   └── AssociationCatalog.swift
│   ├── Services/
│   │   ├── WorkspaceClient.swift
│   │   ├── SystemWorkspaceClient.swift
│   │   ├── ApplicationInventory.swift
│   │   ├── ChangePlanner.swift
│   │   └── ChangeExecutor.swift
│   └── Preferences/
│       ├── AppLanguage.swift
│       └── PreferencesStore.swift
└── DeflyApp/
    ├── DeflyApp.swift
    ├── AppContainer.swift
    ├── Resources/Localizable.xcstrings
    └── UI/
        ├── AppShellView.swift
        ├── Components/ApplicationIconView.swift
        ├── Components/GlassCard.swift
        ├── Overview/OverviewView.swift
        ├── Overview/OverviewViewModel.swift
        ├── Explorer/ExplorerView.swift
        ├── Explorer/ExplorerViewModel.swift
        ├── Applications/ApplicationsView.swift
        ├── Settings/SettingsView.swift
        └── Change/ChangeConfirmationSheet.swift
Tests/
├── DeflyCoreTests/
│   ├── TestSupport.swift
│   ├── AssociationIDTests.swift
│   ├── BuiltInAssociationCatalogTests.swift
│   ├── ChangePlannerTests.swift
│   ├── ChangeExecutorTests.swift
│   └── PreferencesStoreTests.swift
└── DeflyUITests/
    └── DeflyUITests.swift
```

Each file has one responsibility. `WorkspaceClient` is the only default-handler system boundary; views consume ViewModel snapshots and never call `NSWorkspace` directly.

### Task 1: Generate the project and establish domain identity

**Files:**

- Create: `project.yml`
- Modify: `.gitignore`
- Create: `Sources/DeflyCore/Models/AssociationID.swift`
- Create: `Sources/DeflyApp/DeflyApp.swift`
- Create: `Tests/DeflyCoreTests/AssociationIDTests.swift`

**Interfaces:**

- Produces: `AssociationID`, `AssociationID.stableKey`, and an Xcode project with `Defly`, `DeflyCore`, `DeflyCoreTests`, and `DeflyUITests` targets.

- [ ] **Step 1: Write the failing identity tests**

```swift
import XCTest
@testable import DeflyCore

final class AssociationIDTests: XCTestCase {
    func testURLSchemeIsTrimmedAndLowercased() throws {
        let id = try AssociationID.makeURLScheme(" HTTPS ")
        XCTAssertEqual(id, .urlScheme("https"))
        XCTAssertEqual(id.stableKey, "scheme:https")
    }

    func testContentTypeRejectsBlankIdentifier() {
        XCTAssertThrowsError(try AssociationID.makeContentType("   "))
    }
}
```

- [ ] **Step 2: Create `project.yml`, a minimal app entry point, and generate the project**

```yaml
name: Defly
options:
  bundleIdPrefix: com.mapleyf
  deploymentTarget:
    macOS: "14.0"
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MACOSX_DEPLOYMENT_TARGET: "14.0"
targets:
  DeflyCore:
    type: framework
    platform: macOS
    sources: [Sources/DeflyCore]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mapleyf.DeflyCore
        CODE_SIGNING_ALLOWED: NO
  Defly:
    type: application
    platform: macOS
    sources: [Sources/DeflyApp]
    dependencies:
      - target: DeflyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.mapleyf.Defly
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Defly
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.utilities
        ENABLE_HARDENED_RUNTIME: YES
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_ENTITLEMENTS: ""
  DeflyCoreTests:
    type: bundle.unit-test
    platform: macOS
    sources: [Tests/DeflyCoreTests]
    dependencies:
      - target: DeflyCore
    settings:
      base:
        CODE_SIGNING_ALLOWED: NO
  DeflyUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [Tests/DeflyUITests]
    dependencies:
      - target: Defly
schemes:
  DeflyCore:
    build:
      targets:
        DeflyCore: all
    test:
      targets:
        - DeflyCoreTests
  Defly:
    build:
      targets:
        Defly: all
    test:
      targets:
        - DeflyCoreTests
        - DeflyUITests
```

Run: `xcodegen generate`

Expected: `Defly.xcodeproj` is generated without warnings.

- [ ] **Step 3: Run the test to verify the missing type fails**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because `AssociationID` does not exist.

- [ ] **Step 4: Implement normalized association identity**

```swift
import Foundation

public enum AssociationID: Hashable, Codable, Sendable {
    case contentType(String)
    case urlScheme(String)

    public enum ValidationError: Error, Equatable {
        case emptyIdentifier
    }

    public static func makeContentType(_ rawValue: String) throws -> Self {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ValidationError.emptyIdentifier }
        return .contentType(value)
    }

    public static func makeURLScheme(_ rawValue: String) throws -> Self {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty else { throw ValidationError.emptyIdentifier }
        return .urlScheme(value)
    }

    public var stableKey: String {
        switch self {
        case .contentType(let identifier): "type:\(identifier)"
        case .urlScheme(let scheme): "scheme:\(scheme)"
        }
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add .gitignore project.yml Sources/DeflyCore Sources/DeflyApp/DeflyApp.swift Tests/DeflyCoreTests
git commit -m "build(工程): 建立 Defly 原生项目"
```

### Task 2: Implement the public `NSWorkspace` boundary

**Files:**

- Create: `Sources/DeflyCore/Models/HandlerApplication.swift`
- Create: `Sources/DeflyCore/Services/WorkspaceClient.swift`
- Create: `Sources/DeflyCore/Services/SystemWorkspaceClient.swift`
- Create: `Tests/DeflyCoreTests/TestSupport.swift`
- Modify: `Tests/DeflyCoreTests/AssociationIDTests.swift`

**Interfaces:**

- Consumes: `AssociationID`
- Produces: `HandlerApplication` and `@MainActor WorkspaceClient`

- [ ] **Step 1: Add representative URL and application identity tests**

```swift
func testRepresentativeURLUsesNormalizedScheme() throws {
    let id = try AssociationID.makeURLScheme("HTTPS")
    XCTAssertEqual(id.representativeURL?.absoluteString, "https:")
}

func testHandlerIdentityPrefersBundleIdentifier() {
    let app = HandlerApplication(
        applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari",
        compatibility: .systemCandidate
    )
    XCTAssertEqual(app.stableID, "bundle:com.apple.Safari")
}
```

Add shared test fixtures:

```swift
import Foundation
@testable import DeflyCore

enum TestApps {
    static let safari = HandlerApplication(
        applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
        bundleIdentifier: "com.apple.Safari",
        displayName: "Safari",
        compatibility: .systemCandidate
    )

    static let arc = HandlerApplication(
        applicationURL: URL(fileURLWithPath: "/Applications/Arc.app"),
        bundleIdentifier: "company.thebrowser.Browser",
        displayName: "Arc",
        compatibility: .systemCandidate
    )
}

enum TestError: Error {
    case denied
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because representative URLs and `HandlerApplication` are missing.

- [ ] **Step 3: Implement the models and protocol**

```swift
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

    public var id: String { stableID }
}

@MainActor
public protocol WorkspaceClient: AnyObject {
    func defaultApplication(for association: AssociationID) -> HandlerApplication?
    func candidateApplications(for association: AssociationID) -> [HandlerApplication]
    func setDefaultApplication(_ application: HandlerApplication, for association: AssociationID) async throws
}
```

Add to `AssociationID`:

```swift
public var representativeURL: URL? {
    guard case .urlScheme(let scheme) = self else { return nil }
    return URL(string: "\(scheme):")
}
```

- [ ] **Step 4: Implement `SystemWorkspaceClient`**

```swift
import AppKit
import UniformTypeIdentifiers

@MainActor
public final class SystemWorkspaceClient: WorkspaceClient {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func defaultApplication(for association: AssociationID) -> HandlerApplication? {
        let url: URL?
        switch association {
        case .contentType(let identifier):
            url = UTType(identifier).flatMap { workspace.urlForApplication(toOpen: $0) }
        case .urlScheme:
            url = association.representativeURL.flatMap { workspace.urlForApplication(toOpen: $0) }
        }
        return url.map { makeApplication(url: $0, compatibility: .systemCandidate) }
    }

    public func candidateApplications(for association: AssociationID) -> [HandlerApplication] {
        let urls: [URL]
        switch association {
        case .contentType(let identifier):
            urls = UTType(identifier).map { workspace.urlsForApplications(toOpen: $0) } ?? []
        case .urlScheme:
            urls = association.representativeURL.map { workspace.urlsForApplications(toOpen: $0) } ?? []
        }
        return urls.map { makeApplication(url: $0, compatibility: .systemCandidate) }
    }

    public func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        switch association {
        case .contentType(let identifier):
            guard let type = UTType(identifier) else {
                throw WorkspaceError.unresolvableContentType(identifier)
            }
            try await workspace.setDefaultApplication(at: application.applicationURL, toOpen: type)
        case .urlScheme(let scheme):
            try await workspace.setDefaultApplication(
                at: application.applicationURL,
                toOpenURLsWithScheme: scheme
            )
        }
    }

    private func makeApplication(
        url: URL,
        compatibility: HandlerApplication.Compatibility
    ) -> HandlerApplication {
        let bundle = Bundle(url: url)
        return HandlerApplication(
            applicationURL: url,
            bundleIdentifier: bundle?.bundleIdentifier,
            displayName: FileManager.default.displayName(atPath: url.path),
            compatibility: compatibility
        )
    }
}

public enum WorkspaceError: Error, Equatable {
    case unresolvableContentType(String)
}
```

- [ ] **Step 5: Run tests, build the app, and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Run: `xcodebuild build -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: both commands PASS.

Commit:

```bash
git add Sources/DeflyCore Tests/DeflyCoreTests
git commit -m "feat(核心): 封装默认应用系统接口"
```

### Task 3: Build the discoverable association catalog

**Files:**

- Create: `Sources/DeflyCore/Models/AssociationDescriptor.swift`
- Create: `Sources/DeflyCore/Catalog/BuiltInAssociationCatalog.swift`
- Create: `Sources/DeflyCore/Catalog/AssociationCatalog.swift`
- Create: `Sources/DeflyCore/Services/ApplicationInventory.swift`
- Create: `Tests/DeflyCoreTests/BuiltInAssociationCatalogTests.swift`

**Interfaces:**

- Consumes: `AssociationID`
- Produces: `AssociationDescriptor`, `SmartGroupDefinition`, `AssociationCatalog.snapshot()`, and `ApplicationInventory.applications()`

- [ ] **Step 1: Write catalog tests**

```swift
import XCTest
@testable import DeflyCore

final class BuiltInAssociationCatalogTests: XCTestCase {
    func testBrowserGroupContainsThreeAtomicAssociations() {
        let browser = BuiltInAssociationCatalog.smartGroups.first { $0.id == "browser" }
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
        XCTAssertEqual(Set(catalog.snapshot().map(\.id)).count, catalog.snapshot().count)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because catalog types are missing.

- [ ] **Step 3: Implement descriptors, smart groups, and catalog merging**

```swift
public struct AssociationDescriptor: Hashable, Sendable, Identifiable {
    public enum Category: String, CaseIterable, Sendable {
        case web, communication, document, image, media, development, archive
    }

    public let association: AssociationID
    public let localizationKey: String
    public let category: Category
    public let filenameExtensions: [String]
    public let mimeTypes: [String]
    public var id: String { association.stableKey }
}

public struct SmartGroupDefinition: Hashable, Sendable, Identifiable {
    public let id: String
    public let localizationKey: String
    public let associations: [AssociationID]
}

public struct AssociationCatalog: Sendable {
    private let descriptorsByID: [String: AssociationDescriptor]

    public init(seed: [AssociationDescriptor]) {
        descriptorsByID = Dictionary(seed.map { ($0.id, $0) }, uniquingKeysWith: { current, _ in current })
    }

    public func snapshot() -> [AssociationDescriptor] {
        descriptorsByID.values.sorted { $0.id < $1.id }
    }
}

public enum BuiltInAssociationCatalog {
    public static let descriptors: [AssociationDescriptor] = [
        .init(association: .urlScheme("http"), localizationKey: "association.http", category: .web, filenameExtensions: [], mimeTypes: []),
        .init(association: .urlScheme("https"), localizationKey: "association.https", category: .web, filenameExtensions: [], mimeTypes: []),
        .init(association: .urlScheme("mailto"), localizationKey: "association.mailto", category: .communication, filenameExtensions: [], mimeTypes: []),
        .init(association: .contentType("public.html"), localizationKey: "association.html", category: .web, filenameExtensions: ["html", "htm"], mimeTypes: ["text/html"]),
        .init(association: .contentType("com.adobe.pdf"), localizationKey: "association.pdf", category: .document, filenameExtensions: ["pdf"], mimeTypes: ["application/pdf"]),
        .init(association: .contentType("net.daringfireball.markdown"), localizationKey: "association.markdown", category: .development, filenameExtensions: ["md", "markdown"], mimeTypes: ["text/markdown"]),
        .init(association: .contentType("public.plain-text"), localizationKey: "association.plainText", category: .document, filenameExtensions: ["txt"], mimeTypes: ["text/plain"]),
        .init(association: .contentType("public.png"), localizationKey: "association.png", category: .image, filenameExtensions: ["png"], mimeTypes: ["image/png"]),
        .init(association: .contentType("public.jpeg"), localizationKey: "association.jpeg", category: .image, filenameExtensions: ["jpg", "jpeg"], mimeTypes: ["image/jpeg"]),
        .init(association: .contentType("public.heic"), localizationKey: "association.heic", category: .image, filenameExtensions: ["heic"], mimeTypes: ["image/heic"]),
        .init(association: .contentType("com.compuserve.gif"), localizationKey: "association.gif", category: .image, filenameExtensions: ["gif"], mimeTypes: ["image/gif"]),
        .init(association: .contentType("public.tiff"), localizationKey: "association.tiff", category: .image, filenameExtensions: ["tif", "tiff"], mimeTypes: ["image/tiff"]),
        .init(association: .contentType("public.audio"), localizationKey: "association.audio", category: .media, filenameExtensions: [], mimeTypes: ["audio/*"]),
        .init(association: .contentType("public.movie"), localizationKey: "association.video", category: .media, filenameExtensions: [], mimeTypes: ["video/*"]),
        .init(association: .contentType("public.archive"), localizationKey: "association.archive", category: .archive, filenameExtensions: ["zip", "tar", "gz"], mimeTypes: ["application/zip"])
    ]

    public static let smartGroups: [SmartGroupDefinition] = [
        .init(
            id: "browser",
            localizationKey: "smartGroup.browser",
            associations: [.urlScheme("http"), .urlScheme("https"), .contentType("public.html")]
        ),
        .init(
            id: "email",
            localizationKey: "smartGroup.email",
            associations: [.urlScheme("mailto")]
        ),
        .init(
            id: "commonImages",
            localizationKey: "smartGroup.commonImages",
            associations: [
                .contentType("public.png"),
                .contentType("public.jpeg"),
                .contentType("public.heic"),
                .contentType("com.compuserve.gif"),
                .contentType("public.tiff")
            ]
        )
    ]
}
```

Browser uses only `http`, `https`, and `public.html` as atomic associations; `.html` and `.htm` remain descriptor tags.

- [ ] **Step 4: Implement installed-app discovery**

```swift
public struct InstalledApplication: Hashable, Sendable, Identifiable {
    public let url: URL
    public let bundleIdentifier: String?
    public let displayName: String
    public let declaredAssociations: Set<AssociationID>
    public var id: String { bundleIdentifier ?? url.standardizedFileURL.path }
}

@MainActor
public final class ApplicationInventory: NSObject {
    private var activeQuery: NSMetadataQuery?
    private var continuation: CheckedContinuation<[InstalledApplication], Never>?

    public func applications() async -> [InstalledApplication] {
        guard activeQuery == nil else { return [] }
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
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        let applications = query.results
            .compactMap { ($0 as? NSMetadataItem)?.value(forAttribute: NSMetadataItemURLKey) as? URL }
            .compactMap(makeApplication(at:))
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
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
        guard let bundle = Bundle(url: url) else { return nil }
        return InstalledApplication(
            url: url,
            bundleIdentifier: bundle.bundleIdentifier,
            displayName: FileManager.default.displayName(atPath: url.path),
            declaredAssociations: declaredAssociations(in: bundle.infoDictionary ?? [:])
        )
    }

    private func declaredAssociations(in info: [String: Any]) -> Set<AssociationID> {
        var result: Set<AssociationID> = []
        let documentTypes = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        documentTypes
            .flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }
            .forEach { result.insert(.contentType($0)) }

        for key in ["UTImportedTypeDeclarations", "UTExportedTypeDeclarations"] {
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
```

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyCore Tests/DeflyCoreTests
git commit -m "feat(目录): 添加关联与应用发现"
```

### Task 4: Plan atomic changes

**Files:**

- Create: `Sources/DeflyCore/Models/ChangeModels.swift`
- Create: `Sources/DeflyCore/Services/ChangePlanner.swift`
- Create: `Tests/DeflyCoreTests/ChangePlannerTests.swift`

**Interfaces:**

- Consumes: `WorkspaceClient`, `[AssociationID]`, and `HandlerApplication`
- Produces: `ChangePlan`

- [ ] **Step 1: Write planner tests with an in-memory workspace**

```swift
@MainActor
final class FakeWorkspaceClient: WorkspaceClient {
    var defaults: [AssociationID: HandlerApplication] = [:]
    var candidates: [AssociationID: [HandlerApplication]] = [:]
    var setErrors: [AssociationID: Error] = [:]

    func defaultApplication(for association: AssociationID) -> HandlerApplication? {
        defaults[association]
    }

    func candidateApplications(for association: AssociationID) -> [HandlerApplication] {
        candidates[association] ?? []
    }

    func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        if let error = setErrors[association] { throw error }
        defaults[association] = application
    }
}

@MainActor
final class ChangePlannerTests: XCTestCase {
    func testPlannerRemovesNoOpAndDeduplicatesAssociations() throws {
        let workspace = FakeWorkspaceClient()
        let safari = TestApps.safari
        let arc = TestApps.arc
        let http = try AssociationID.makeURLScheme("http")
        let https = try AssociationID.makeURLScheme("https")
        workspace.defaults = [http: safari, https: arc]
        workspace.candidates = [http: [safari, arc], https: [safari, arc]]

        let plan = ChangePlanner(workspace: workspace).makePlan(
            associations: [https, http, http],
            target: arc
        )

        XCTAssertEqual(plan.changes.map(\.association), [http])
        XCTAssertEqual(plan.changes.first?.compatibility, .systemCandidate)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because change models and planner are missing.

- [ ] **Step 3: Implement immutable change models**

```swift
public struct PlannedChange: Hashable, Sendable, Identifiable {
    public enum Compatibility: String, Hashable, Sendable {
        case systemCandidate
        case manuallySelected
    }

    public let association: AssociationID
    public let previousHandler: HandlerApplication?
    public let targetHandler: HandlerApplication
    public let compatibility: Compatibility
    public var id: String { association.stableKey }
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
```

- [ ] **Step 4: Implement planner sorting and compatibility**

```swift
@MainActor
public struct ChangePlanner {
    private let workspace: WorkspaceClient

    public init(workspace: WorkspaceClient) {
        self.workspace = workspace
    }

    public func makePlan(
        associations: [AssociationID],
        target: HandlerApplication
    ) -> ChangePlan {
        let unique = Dictionary(
            associations.map { ($0.stableKey, $0) },
            uniquingKeysWith: { current, _ in current }
        )

        let changes = unique.values
            .sorted { $0.stableKey < $1.stableKey }
            .compactMap { association -> PlannedChange? in
                let current = workspace.defaultApplication(for: association)
                guard current?.stableID != target.stableID else { return nil }
                let isCandidate = workspace
                    .candidateApplications(for: association)
                    .contains { $0.stableID == target.stableID }
                return PlannedChange(
                    association: association,
                    previousHandler: current,
                    targetHandler: target,
                    compatibility: isCandidate ? .systemCandidate : .manuallySelected
                )
            }
        return ChangePlan(changes: changes)
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyCore Tests/DeflyCoreTests
git commit -m "feat(变更): 添加原子变更计划"
```

### Task 5: Execute, verify, and retry partial failures

**Files:**

- Modify: `Sources/DeflyCore/Models/ChangeModels.swift`
- Create: `Sources/DeflyCore/Services/ChangeExecutor.swift`
- Create: `Tests/DeflyCoreTests/ChangeExecutorTests.swift`

**Interfaces:**

- Consumes: `ChangePlan`
- Produces: `ChangeReport`, `ChangeItemResult`, and `ChangeReport.retryPlan()`

- [ ] **Step 1: Write mixed-result tests**

```swift
@MainActor
func testExecutorContinuesAfterFailureAndVerifiesReadback() async throws {
    let workspace = FakeWorkspaceClient()
    let http = try AssociationID.makeURLScheme("http")
    let https = try AssociationID.makeURLScheme("https")
    workspace.setErrors[http] = TestError.denied
    let plan = ChangePlan(changes: [
        PlannedChange(association: http, previousHandler: TestApps.safari, targetHandler: TestApps.arc, compatibility: .systemCandidate),
        PlannedChange(association: https, previousHandler: TestApps.safari, targetHandler: TestApps.arc, compatibility: .systemCandidate)
    ])

    let report = await ChangeExecutor(workspace: workspace).execute(plan)

    XCTAssertEqual(report.results.map(\.status), [.failed, .verified])
    XCTAssertEqual(report.retryPlan().changes.map(\.association), [http])
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because executor and report types are missing.

- [ ] **Step 3: Implement result types**

```swift
public struct ChangeItemResult: Sendable, Identifiable {
    public enum Status: String, Sendable {
        case verified
        case failed
        case notApplied
    }

    public let change: PlannedChange
    public let status: Status
    public let errorDescription: String?
    public var id: String { change.id }
}

public struct ChangeReport: Sendable {
    public let sourcePlan: ChangePlan
    public let results: [ChangeItemResult]

    public func retryPlan() -> ChangePlan {
        ChangePlan(
            changes: results
                .filter { $0.status != .verified }
                .map(\.change)
        )
    }
}
```

- [ ] **Step 4: Implement serial execution and readback**

```swift
@MainActor
public final class ChangeExecutor {
    private let workspace: WorkspaceClient

    public init(workspace: WorkspaceClient) {
        self.workspace = workspace
    }

    public func execute(_ plan: ChangePlan) async -> ChangeReport {
        var results: [ChangeItemResult] = []
        for change in plan.changes {
            do {
                try await workspace.setDefaultApplication(
                    change.targetHandler,
                    for: change.association
                )
                let actual = workspace.defaultApplication(for: change.association)
                let status: ChangeItemResult.Status =
                    actual?.stableID == change.targetHandler.stableID
                    ? .verified
                    : .notApplied
                results.append(ChangeItemResult(change: change, status: status, errorDescription: nil))
            } catch {
                results.append(ChangeItemResult(
                    change: change,
                    status: .failed,
                    errorDescription: String(describing: error)
                ))
            }
        }
        return ChangeReport(sourcePlan: plan, results: results)
    }
}
```

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyCore Tests/DeflyCoreTests
git commit -m "feat(变更): 执行并验证默认应用修改"
```

### Task 6: Persist language and pinned items

**Files:**

- Create: `Sources/DeflyCore/Preferences/AppLanguage.swift`
- Create: `Sources/DeflyCore/Preferences/PreferencesStore.swift`
- Create: `Tests/DeflyCoreTests/PreferencesStoreTests.swift`
- Create: `Sources/DeflyApp/Resources/Localizable.xcstrings`

**Interfaces:**

- Produces: `AppLanguage`, `PreferencesStore.language`, and `PreferencesStore.pinnedAssociationKeys`

- [ ] **Step 1: Write isolated UserDefaults tests**

```swift
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
        XCTAssertEqual(restored.pinnedAssociationKeys, ["type:com.adobe.pdf"])
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because preference types are missing.

- [ ] **Step 3: Implement exact preference keys and defaults**

```swift
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}

public struct PreferencesStore {
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
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    public var pinnedAssociationKeys: [String] {
        get { defaults.stringArray(forKey: Key.pinnedAssociations) ?? [] }
        set { defaults.set(newValue, forKey: Key.pinnedAssociations) }
    }
}
```

- [ ] **Step 4: Add String Catalog entries**

Create `Localizable.xcstrings` with `sourceLanguage` set to `zh-Hans` and complete `en` translations for:

```text
nav.overview, nav.fileTypes, nav.urlSchemes, nav.applications, nav.settings
overview.title, overview.subtitle, overview.commonGroups, overview.pinned
action.refresh, action.chooseApplication, action.cancel, action.confirm
change.previewTitle, change.currentApplication, change.newApplication
change.retryFailures, change.complete
settings.language, language.zhHans, language.en
```

Do not use key names as visible fallback strings.

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme DeflyCore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyCore/Preferences Sources/DeflyApp/Resources Tests/DeflyCoreTests
git commit -m "feat(本地化): 添加中文默认语言与偏好"
```

### Task 7: Build the native shell and overview

**Files:**

- Modify: `Sources/DeflyApp/DeflyApp.swift`
- Create: `Sources/DeflyApp/AppContainer.swift`
- Create: `Sources/DeflyApp/FixtureWorkspaceClient.swift`
- Create: `Sources/DeflyApp/UI/AppShellView.swift`
- Create: `Sources/DeflyApp/UI/Components/ApplicationIconView.swift`
- Create: `Sources/DeflyApp/UI/Components/GlassCard.swift`
- Create: `Sources/DeflyApp/UI/Overview/OverviewView.swift`
- Create: `Sources/DeflyApp/UI/Overview/OverviewViewModel.swift`
- Create: `Tests/DeflyUITests/DeflyUITests.swift`

**Interfaces:**

- Consumes: `WorkspaceClient`, `BuiltInAssociationCatalog`, and `PreferencesStore`
- Produces: a launchable sidebar app and overview snapshots

- [ ] **Step 1: Write UI launch tests**

```swift
import XCTest

final class DeflyUITests: XCTestCase {
    func testFirstLaunchIsChineseAndShowsFiveDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-preferences"]
        app.launch()

        XCTAssertTrue(app.staticTexts["概览"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["文件类型"].exists)
        XCTAssertTrue(app.staticTexts["URL 协议"].exists)
        XCTAssertTrue(app.staticTexts["应用"].exists)
        XCTAssertTrue(app.staticTexts["设置"].exists)
    }
}
```

- [ ] **Step 2: Run the UI test and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because the navigation shell is missing.

- [ ] **Step 3: Implement dependency composition and root navigation**

Use:

```swift
enum SidebarDestination: String, CaseIterable, Identifiable {
    case overview, fileTypes, urlSchemes, applications, settings
    var id: String { rawValue }
}
```

Provide deterministic UI fixtures without touching the real system:

```swift
@MainActor
final class FixtureWorkspaceClient: WorkspaceClient {
    private var defaults: [AssociationID: HandlerApplication]
    private let candidates: [HandlerApplication]

    init() {
        let safari = HandlerApplication(
            applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari",
            compatibility: .systemCandidate
        )
        let preview = HandlerApplication(
            applicationURL: URL(fileURLWithPath: "/System/Applications/Preview.app"),
            bundleIdentifier: "com.apple.Preview",
            displayName: "预览",
            compatibility: .systemCandidate
        )
        candidates = [safari, preview]
        defaults = Dictionary(
            uniqueKeysWithValues: BuiltInAssociationCatalog.descriptors.map {
                ($0.association, $0.category == .web ? safari : preview)
            }
        )
    }

    func defaultApplication(for association: AssociationID) -> HandlerApplication? {
        defaults[association]
    }

    func candidateApplications(for association: AssociationID) -> [HandlerApplication] {
        candidates
    }

    func setDefaultApplication(
        _ application: HandlerApplication,
        for association: AssociationID
    ) async throws {
        defaults[association] = application
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let workspace: WorkspaceClient
    let catalog = AssociationCatalog(seed: BuiltInAssociationCatalog.descriptors)

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        workspace = arguments.contains("-use-fixtures")
            ? FixtureWorkspaceClient()
            : SystemWorkspaceClient()
    }
}
```

Build `NavigationSplitView` with system symbols:

```text
overview → rectangle.grid.2x2
fileTypes → doc
urlSchemes → link
applications → app.dashed
settings → gearshape
```

Set `.tint(.blue)`, use a minimum window size of `880 × 600`, and default size `1040 × 720`.

- [ ] **Step 4: Implement grouped overview**

`OverviewViewModel.refresh()` reads browser, email, PDF, Markdown, and common image assignments through `WorkspaceClient`. `OverviewView` renders:

- sync state and refresh button
- “常用组合” with Browser and Email
- “已固定” with stored pins or PDF, Markdown, Common Images defaults
- real icons through `NSWorkspace.shared.icon(forFile:)`
- no direct write action on card selection

Use `GlassCard` backed by `.regularMaterial`; when `accessibilityReduceTransparency` is true, use `Color(nsColor: .windowBackgroundColor)`.

- [ ] **Step 5: Run UI and core tests, then commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyApp Tests/DeflyUITests
git commit -m "feat(界面): 实现原生概览与导航"
```

### Task 8: Implement file, scheme, and app explorers

**Files:**

- Create: `Sources/DeflyApp/UI/Explorer/ExplorerView.swift`
- Create: `Sources/DeflyApp/UI/Explorer/ExplorerViewModel.swift`
- Create: `Sources/DeflyApp/UI/Applications/ApplicationsView.swift`
- Modify: `Sources/DeflyApp/UI/AppShellView.swift`
- Modify: `Tests/DeflyUITests/DeflyUITests.swift`

**Interfaces:**

- Consumes: catalog snapshots, application inventory, and `WorkspaceClient`
- Produces: searchable two-pane file and scheme explorers plus app-oriented browsing

- [ ] **Step 1: Add UI tests for search and detail selection**

```swift
func testFileTypeSearchSelectsPDFAndShowsIdentifier() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-use-fixtures"]
    app.launch()
    app.staticTexts["文件类型"].click()
    let search = app.searchFields.firstMatch
    search.click()
    search.typeText("pdf")
    app.staticTexts["PDF 文档"].click()
    XCTAssertTrue(app.staticTexts["com.adobe.pdf"].exists)
}
```

- [ ] **Step 2: Run the UI test and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because explorer views are missing.

- [ ] **Step 3: Implement reusable two-pane explorer**

`ExplorerViewModel` accepts a mode:

```swift
enum ExplorerMode: Sendable {
    case contentTypes
    case urlSchemes
}
```

It filters descriptors by localized name, stable identifier, extension, and MIME type. The left pane is a `List(selection:)`; the right inspector displays current handler, metadata, candidates, and a “选择其他应用…” button.

- [ ] **Step 4: Implement applications view**

Load `ApplicationInventory.applications()`, show name and Bundle ID in the list, and group the selected app’s declared associations by content type and Scheme. Query `WorkspaceClient` before labeling an association as currently assigned.

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyApp Tests/DeflyUITests
git commit -m "feat(高级管理): 添加关联与应用浏览器"
```

### Task 9: Add native confirmation, execution, and retry

**Files:**

- Create: `Sources/DeflyApp/UI/Change/ChangeConfirmationSheet.swift`
- Modify: `Sources/DeflyApp/UI/Explorer/ExplorerView.swift`
- Modify: `Sources/DeflyApp/UI/Overview/OverviewView.swift`
- Modify: `Sources/DeflyApp/UI/Applications/ApplicationsView.swift`
- Modify: `Tests/DeflyUITests/DeflyUITests.swift`

**Interfaces:**

- Consumes: `ChangePlanner`, `ChangeExecutor`, and `ChangePlan`
- Produces: confirmation, in-progress, and result states

- [ ] **Step 1: Add fixture-backed UI tests**

```swift
func testChangeRequiresConfirmationAndRetriesOnlyFailure() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-use-fixtures", "-fixture-partial-failure"]
    app.launch()
    app.buttons["更改默认应用"].click()
    app.buttons["Arc"].click()

    XCTAssertTrue(app.sheets.staticTexts["确认更改默认应用？"].exists)
    XCTAssertTrue(app.sheets.staticTexts["http"].exists)
    XCTAssertTrue(app.sheets.staticTexts["https"].exists)
    XCTAssertFalse(app.sheets.staticTexts[".html"].label.isEmpty)

    app.sheets.buttons["确认更改"].click()
    XCTAssertTrue(app.sheets.buttons["重试失败项"].waitForExistence(timeout: 3))
}
```

- [ ] **Step 2: Run the UI test and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because no change sheet exists.

- [ ] **Step 3: Implement sheet state**

```swift
@MainActor
final class ChangeSheetModel: ObservableObject {
    enum Phase {
        case preview(ChangePlan)
        case applying(ChangePlan)
        case result(ChangeReport)
    }

    @Published private(set) var phase: Phase
    private let executor: ChangeExecutor

    init(plan: ChangePlan, executor: ChangeExecutor) {
        phase = .preview(plan)
        self.executor = executor
    }

    func confirm() async {
        guard case .preview(let plan) = phase else { return }
        phase = .applying(plan)
        phase = .result(await executor.execute(plan))
    }

    func retryFailures() async {
        guard case .result(let report) = phase else { return }
        let plan = report.retryPlan()
        phase = .applying(plan)
        phase = .result(await executor.execute(plan))
    }
}
```

- [ ] **Step 4: Implement native Sheet UI**

The sheet must show:

- previous and target real app icons
- every atomic association
- extension/MIME explanatory tags in a visually separate row
- manually selected compatibility warning
- Cancel and Confirm controls in preview
- disabled dismissal during execution
- per-item verified, failed, or not-applied state
- “重试失败项” only when failures exist
- refresh callback after completion

- [ ] **Step 5: Run tests and commit**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: PASS.

Commit:

```bash
git add Sources/DeflyApp Tests/DeflyUITests
git commit -m "feat(变更界面): 添加确认与失败重试"
```

### Task 10: Finish settings, accessibility, and release verification

**Files:**

- Create: `Sources/DeflyApp/UI/Settings/SettingsView.swift`
- Modify: `Sources/DeflyApp/UI/AppShellView.swift`
- Modify: `Sources/DeflyApp/Resources/Localizable.xcstrings`
- Modify: `README.md`
- Create: `scripts/verify.sh`
- Modify: `Tests/DeflyUITests/DeflyUITests.swift`

**Interfaces:**

- Consumes: `PreferencesStore` and all implemented app flows
- Produces: complete V1 verification command

- [ ] **Step 1: Add language persistence and accessibility UI tests**

```swift
func testEnglishPersistsAcrossRelaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-reset-preferences"]
    app.launch()
    app.staticTexts["设置"].click()
    app.popUpButtons["语言"].click()
    app.menuItems["English"].click()
    XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 2))
    app.terminate()
    app.launchArguments = ["-ui-testing"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Overview"].exists)
}
```

- [ ] **Step 2: Run the UI test and verify failure**

Run: `xcodebuild test -project Defly.xcodeproj -scheme Defly -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`

Expected: FAIL because settings language switching is missing.

- [ ] **Step 3: Implement settings and root locale**

Bind the root view locale to:

```swift
.environment(\.locale, Locale(identifier: preferences.language.rawValue))
```

Settings uses a `Picker` for `zh-Hans` and `en`, persists on change, and includes version plus repository links. Every icon-only button gets an accessibility label.

- [ ] **Step 4: Add a deterministic verification script**

```bash
#!/usr/bin/env bash
set -euo pipefail
xcodegen generate
xcodebuild test \
  -project Defly.xcodeproj \
  -scheme DeflyCore \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Defly.xcodeproj \
  -scheme Defly \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 5: Update README build instructions and run final verification**

Document:

```bash
xcodegen generate
./scripts/verify.sh
open Defly.xcodeproj
```

Run: `./scripts/verify.sh`

Expected: all core tests pass and the macOS app builds.

- [ ] **Step 6: Inspect the built app**

Launch the Debug app and manually verify:

```text
Chinese first launch
English switch and relaunch persistence
system-blue light and dark appearance
Reduce Transparency behavior
keyboard navigation through all sidebar destinations
VoiceOver labels for icons and status
browser change preview lists http, https, and public.html only
Cancel performs no writes
partial failure preserves verified changes
no Defly background process after quit
```

- [ ] **Step 7: Commit**

```bash
git add Sources Tests scripts README.md project.yml .gitignore
git commit -m "feat(应用): 完成 Defly V1 默认应用管理"
```
