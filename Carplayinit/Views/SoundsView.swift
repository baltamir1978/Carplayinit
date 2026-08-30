import SwiftUI
import UniformTypeIdentifiers

/// Chime picker: pick one, hear it, or bring in your own.
struct SoundsView: View {
    @State private var library = SoundLibrary.shared
    @State private var player = StartupSoundPlayer.shared
    @State private var showingImporter = false
    @State private var pendingImportURL: URL?
    @State private var showingMixer = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sonido al conectar", isOn: Binding(
                        get: { SharedStore.startupSoundEnabled },
                        set: { SharedStore.startupSoundEnabled = $0 }
                    ))
                    Toggle("También al desconectar", isOn: Binding(
                        get: { SharedStore.playsOnDisconnect },
                        set: { SharedStore.playsOnDisconnect = $0 }
                    ))
                } footer: {
                    Text("CarPlay siempre hace sonar primero su propio aviso: el tuyo entra justo detrás.")
                }

                ForEach(library.packs) { pack in
                    packSection(pack)
                }

                Section {
                    Button("Importar un audio", systemImage: "square.and.arrow.down") {
                        showingImporter = true
                    }
                    Button("Mezclar dos pistas", systemImage: "waveform.badge.plus") {
                        showingMixer = true
                    }
                } footer: {
                    Text("Eliges el trozo sobre la onda; máximo 10 s, y se nivela a −12 dBFS para que no pegue un susto en el coche. Los temas de Apple Music con DRM no se pueden importar: usa un archivo de la app Archivos.")
                }
            }
            .navigationTitle("Sonidos")
            .overlay {
                if library.isPreparing {
                    ProgressView("Preparando sonidos…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio]) { result in
                // Straight to the trimmer: the fragment worth keeping is rarely the
                // first seconds of the file.
                guard case .success(let url) = result else { return }
                pendingImportURL = url
            }
            .sheet(item: $pendingImportURL) { url in
                TrimSoundView(sourceURL: url)
            }
            .sheet(isPresented: $showingMixer) {
                MixerView()
            }
        }
    }

    /// Pulled out of `body`: one `List` with everything inline blows the
    /// type-checker's budget.
    @ViewBuilder
    private func packSection(_ pack: SoundPack) -> some View {
        Section {
            ForEach(pack.sounds) { sound in
                SoundRow(
                    sound: sound,
                    isSelected: SharedStore.selectedSoundID == sound.id,
                    isPlaying: player.playingSoundID == sound.id,
                    onPlay: { player.play(sound) },
                    onSelect: { library.select(sound) }
                )
                .swipeActions {
                    if pack.id == SoundLibrary.importedPackID {
                        Button("Eliminar", role: .destructive) {
                            library.deleteImported(sound)
                        }
                    }
                }
            }
        } header: {
            Label(pack.name, systemImage: pack.symbol)
        } footer: {
            Text(pack.subtitle)
        }
    }
}

// MARK: - Row

struct SoundRow: View {
    let sound: StartupSound
    let isSelected: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(sound.name)
                Text(String(format: "%.1f s", sound.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Mixer

/// Builds a chime out of two files: a lead over a bed. The bed is ducked and faded
/// so the lead stays intelligible over a car's speakers.
struct MixerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var library = SoundLibrary.shared

    @State private var foregroundURL: URL?
    @State private var backgroundURL: URL?
    @State private var backgroundGain: Double = 0.35
    @State private var name = "Mi mezcla"
    @State private var pickingForeground = false
    @State private var pickingBackground = false
    @State private var isWorking = false
    @State private var error: String?

    private var canMix: Bool { foregroundURL != nil && backgroundURL != nil && !isWorking }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                }

                Section {
                    filePicker(url: foregroundURL, placeholder: "Elegir voz o tema principal") {
                        pickingForeground = true
                    }
                } header: {
                    Text("Pista principal")
                } footer: {
                    Text("Manda sobre la mezcla: su duración fija la del resultado (máx. 10 s).")
                }

                Section {
                    filePicker(url: backgroundURL, placeholder: "Elegir música de fondo") {
                        pickingBackground = true
                    }
                    LabeledContent("Nivel del fondo") {
                        Slider(value: $backgroundGain, in: 0.05...1)
                    }
                    Text("\(Int(backgroundGain * 100)) %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Fondo")
                } footer: {
                    Text("Si el fondo es más corto, se repite hasta cubrir la principal. Entra y sale con fundido.")
                }

                Section {
                    Button {
                        mix()
                    } label: {
                        if isWorking {
                            HStack { ProgressView(); Text("Mezclando…") }
                        } else {
                            Text("Crear sonido")
                        }
                    }
                    .disabled(!canMix)
                }
            }
            .navigationTitle("Mezclar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .fileImporter(isPresented: $pickingForeground, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { foregroundURL = url }
            }
            .fileImporter(isPresented: $pickingBackground, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { backgroundURL = url }
            }
            .alert("No se pudo mezclar", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }

    @ViewBuilder
    private func filePicker(url: URL?, placeholder: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: url == nil ? "plus.circle" : "waveform")
                Text(url?.lastPathComponent ?? placeholder)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
    }

    private func mix() {
        guard let foregroundURL, let backgroundURL else { return }
        isWorking = true
        Task {
            do {
                try await library.mixSounds(foreground: foregroundURL,
                                            background: backgroundURL,
                                            backgroundGain: Float(backgroundGain),
                                            name: name)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isWorking = false
        }
    }
}
