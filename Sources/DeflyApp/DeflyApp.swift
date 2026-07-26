import SwiftUI

@main
struct DeflyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Defly")
                .frame(minWidth: 880, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 720)
    }
}
