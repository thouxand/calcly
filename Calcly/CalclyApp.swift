import SwiftUI

@main
struct CalclyApp: App {
    @StateObject private var store = ProgressStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Lær", systemImage: "graduationcap.fill") { PathView() }
            Tab("Lynrunde", systemImage: "bolt.fill") { QuickView() }
            Tab("Kort", systemImage: "rectangle.on.rectangle.angled") { CardsView() }
            Tab("Profil", systemImage: "person.crop.circle.fill") { ProfileView() }
        }
    }
}

/// Saves progress as JSON in UserDefaults whenever it changes.
@MainActor
final class ProgressStore: ObservableObject {
    private static let key = "progress"

    @Published var state: ProgressState {
        didSet { if state != oldValue { save() } }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(ProgressState.self, from: data) {
            state = saved
        } else {
            state = ProgressState()
        }
        state.refillHearts()
    }

    func refresh() { state.refillHearts() }

    func reset() { state = ProgressState() }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}
