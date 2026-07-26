import SwiftUI

@main
struct DeflyApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppShellView(container: container)
                .environment(
                    \.locale,
                    Locale(identifier: container.language.rawValue)
                )
                .frame(minWidth: 880, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 720)
    }
}
