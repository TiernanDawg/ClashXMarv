import SwiftUI

@main
struct VanguardArenaApp: App {
    @StateObject private var profile = ProfileStore.shared
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(profile).preferredColorScheme(.dark).environment(\.dynamicTypeSize, profile.profile.settings.largeText ? .xxxLarge : .large)
        }
    }
}