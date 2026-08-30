import SwiftUI

struct RootView: View {
    @State private var selection: TabID = .garage

    /// Named `TabID` so it does not shadow SwiftUI's own `Tab` view.
    enum TabID: Hashable { case garage, sounds, settings }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Garaje", systemImage: "car.fill", value: TabID.garage) {
                GarageView()
            }
            Tab("Sonidos", systemImage: "speaker.wave.2.fill", value: TabID.sounds) {
                SoundsView()
            }
            Tab("Ajustes", systemImage: "gearshape.fill", value: TabID.settings) {
                SettingsView()
            }
        }
        // Irse de la pestaña calla lo que sonara: con clips de hasta un minuto,
        // seguir oyéndolo desde otra pantalla es desconcertante.
        .onChange(of: selection) { _, _ in
            StartupSoundPlayer.shared.stop()
        }
    }
}

#Preview {
    RootView()
}
