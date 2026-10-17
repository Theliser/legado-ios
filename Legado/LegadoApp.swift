import SwiftUI

@main
struct LegadoApp: App {
    @StateObject private var environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
        }
    }
}
