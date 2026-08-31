import SwiftUI

struct SettingsView: View {
    @State private var watcher = CarConnectionWatcher.shared
    @State private var library = SoundLibrary.shared
    @State private var volume: Double = SharedStore.outputVolume

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GuideView()
                    } label: {
                        Label("Cómo se usa", systemImage: "book.fill")
                    }
                }

                Section {
                    Toggle("Sonido de arranque", isOn: $library.isEnabled)
                } footer: {
                    Text("""
                    El interruptor de todo: apagado, no suena nada al entrar ni al salir del coche, \
                    ni cuando lo dispara una automatización de Atajos. «Probar ahora» sigue sonando — es una escucha que pides tú.
                    """)
                }

                Section("Reproducción") {
                    LabeledContent("Volumen") {
                        Slider(value: $volume, in: 0.1...1) {
                            Text("Volumen")
                        } minimumValueLabel: {
                            Image(systemName: "speaker.fill").font(.caption)
                        } maximumValueLabel: {
                            Image(systemName: "speaker.wave.3.fill").font(.caption)
                        }
                        .onChange(of: volume) { _, newValue in
                            SharedStore.outputVolume = newValue
                        }
                    }
                    Button("Probar ahora", systemImage: "play.circle") {
                        StartupSoundPlayer.shared.playSelected()
                    }
                }

                Section {
                    Toggle("Mantener a la escucha", isOn: $watcher.keepAliveEnabled)
                } header: {
                    Text("Detección")
                } footer: {
                    Text("""
                    Mantiene la app despierta en segundo plano para reconocer el momento en que el móvil entra en el coche. \
                    Gasta algo de batería. Si lo desactivas, el sonido sólo suena cuando la app ya está en marcha — para lo demás, usa la automatización de Atajos.
                    """)
                }

                Section("Estado") {
                    LabeledContent("Salida de audio",
                                   value: watcher.currentRouteName.isEmpty ? "—" : watcher.currentRouteName)
                    LabeledContent("En el coche", value: watcher.isConnectedToCar ? "Sí" : "No")
                    if let last = watcher.lastConnectionDate {
                        LabeledContent("Última conexión",
                                       value: last.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                Section {
                    NavigationLink {
                        ShortcutsGuideView()
                    } label: {
                        Label("Automatización con Atajos", systemImage: "wand.and.stars")
                    }
                } footer: {
                    Text("La vía a prueba de balas: se dispara aunque la app esté cerrada.")
                }

                Section {
                    LabeledContent("Widgets", value: "Mantén pulsado → Editar widget")
                } footer: {
                    Text("En iOS 26 el salpicadero de CarPlay muestra los widgets del iPhone: Ajustes → General → CarPlay → tu coche → Personalizar.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
