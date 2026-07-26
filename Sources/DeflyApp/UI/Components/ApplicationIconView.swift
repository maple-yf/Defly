import AppKit
import DeflyCore
import SwiftUI

struct ApplicationIconView: View {
    let application: HandlerApplication?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let application {
                Image(
                    nsImage: NSWorkspace.shared.icon(
                        forFile: application.applicationURL.path
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
