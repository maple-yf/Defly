import AppKit
import DeflyCore
import SwiftUI

struct ApplicationIconView: View {
    private let applicationURL: URL?
    var size: CGFloat = 44

    init(
        application: HandlerApplication?,
        size: CGFloat = 44
    ) {
        applicationURL = application?.applicationURL
        self.size = size
    }

    init(
        installedApplication: InstalledApplication?,
        size: CGFloat = 44
    ) {
        applicationURL = installedApplication?.url
        self.size = size
    }

    var body: some View {
        Group {
            if let applicationURL {
                Image(
                    nsImage: NSWorkspace.shared.icon(
                        forFile: applicationURL.path
                    )
                )
                .resizable()
                .scaledToFit()
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
