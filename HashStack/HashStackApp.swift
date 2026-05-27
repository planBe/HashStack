import SwiftUI

@main
struct HashStackApp: App {
    var body: some Scene {
        MenuBarExtra("HashStack", systemImage: "number") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
