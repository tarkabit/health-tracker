import SwiftUI

@main
struct HealthTrackerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reload from Disk") { state.reload() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
