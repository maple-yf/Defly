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
