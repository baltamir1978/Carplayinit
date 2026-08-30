import SwiftUI
import AVFoundation

/// Picks the fragment to keep from an imported file.
///
/// Needed because the interesting second of a clip pulled off a video is almost
/// never the first one: without this the importer would just take the head of the
/// file and there would be no way to reach the rest.
struct TrimSoundView: View {
    let sourceURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var library = SoundLibrary.shared

    @State private var name: String
    @State private var waveform: AudioNormalizer.Waveform?
    @State private var start: Double = 0
    @State private var length: Double = 3
    @State private var isSaving = false
    @State private var error: String?
    @State private var player = StartupSoundPlayer.shared
    @State private var hasScope = false

    init(sourceURL: URL) {
        self.sourceURL = sourceURL
        _name = State(initialValue: sourceURL.deletingPathExtension().lastPathComponent)
    }

    private var duration: Double { waveform?.duration ?? 0 }
    private var maxLength: Double { min(AudioNormalizer.maxDuration, max(duration, 0.5)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                }

                Section {
                    if let waveform {
                        WaveformScrubber(peaks: waveform.peaks,
                                         duration: waveform.duration,
                                         start: $start,
                                         length: $length)
                            .frame(height: 120)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } else {
                        HStack {
                            ProgressView()
                            Text("Leyendo el audio…").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Fragmento")
                } footer: {
                    Text("Arrastra sobre la onda para mover el trozo. Los bordes llevan un fundido corto para que no chasquee al cortar por el medio.")
                }

                if waveform != nil {
                    Section {
                        LabeledContent("Empieza en") {
                            Slider(value: $start, in: 0...max(duration - 0.2, 0.2))
                        }
                        Text(timecode(start))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        LabeledContent("Dura") {
                            // Recorrido cuadrático: con el tope en 60 s, un slider
                            // lineal deja los tres primeros segundos —que es lo que
                            // suele durar un sonido de arranque— en un pelo del
                            // extremo izquierdo. Así la mitad del dedo son 15 s.
                            Slider(value: Binding(
                                get: { sqrt(min(length, maxLength) / maxLength) },
                                set: { length = max(0.3, $0 * $0 * maxLength) }
                            ), in: 0...1)
                        }
                        Text(length < 60
                             ? String(format: "%.1f s", length)
                             : timecode(length))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button(player.isPlayingExcerpt ? "Parar" : "Escuchar el trozo",
                               systemImage: player.isPlayingExcerpt ? "stop.circle" : "play.circle") {
                            player.isPlayingExcerpt ? stopPreview() : preview()
                        }
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            HStack { ProgressView(); Text("Guardando…") }
                        } else {
                            Text("Guardar como sonido")
                        }
                    }
                    .disabled(waveform == nil || isSaving)
                } footer: {
                    Text("Se nivela a −12 dBFS, como el resto de sonidos. Después toca su círculo en la lista para dejarlo como sonido de arranque.")
                }
            }
            .navigationTitle("Recortar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        stopPreview()
                        dismiss()
                    }
                }
            }
            .task { await load() }
            .onDisappear {
                stopPreview()
                if hasScope { sourceURL.stopAccessingSecurityScopedResource() }
            }
            .alert("No se pudo leer", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) {
                Button("Vale", role: .cancel) { dismiss() }
            } message: {
                Text(error ?? "")
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        // Hold the scope open for the whole screen: preview and save both read it.
        hasScope = sourceURL.startAccessingSecurityScopedResource()
        do {
            let result = try await AudioNormalizer.waveform(for: sourceURL)
            waveform = result
            length = min(3, result.duration)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func preview() {
        player.playExcerpt(of: sourceURL, from: start, seconds: length)
    }

    private func stopPreview() {
        player.stop()
    }

    private func save() {
        isSaving = true
        stopPreview()
        Task {
            do {
                try await library.importSound(from: sourceURL, name: name,
                                              start: start, length: length)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func timecode(_ seconds: Double) -> String {
        String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60))
    }
}

// MARK: - Waveform

/// Draws the peaks and the selected window, draggable.
struct WaveformScrubber: View {
    let peaks: [Float]
    let duration: Double
    @Binding var start: Double
    @Binding var length: Double

    @State private var dragOrigin: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let windowX = duration > 0 ? width * start / duration : 0
            let windowWidth = duration > 0 ? max(width * length / duration, 6) : 0

            ZStack(alignment: .leading) {
                Canvas { context, size in
                    guard !peaks.isEmpty else { return }
                    let step = size.width / CGFloat(peaks.count)
                    let middle = size.height / 2
                    for (index, peak) in peaks.enumerated() {
                        let barHeight = max(CGFloat(peak) * size.height * 0.92, 1)
                        let rect = CGRect(x: CGFloat(index) * step,
                                          y: middle - barHeight / 2,
                                          width: max(step - 0.7, 0.7),
                                          height: barHeight)
                        context.fill(Path(roundedRect: rect, cornerRadius: 0.5),
                                     with: .color(.secondary.opacity(0.45)))
                    }
                }

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                    .frame(width: windowWidth, height: height)
                    .offset(x: windowX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard duration > 0 else { return }
                        if dragOrigin == nil { dragOrigin = start }
                        let delta = Double(value.translation.width / width) * duration
                        start = min(max((dragOrigin ?? 0) + delta, 0), max(duration - length, 0))
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
        }
    }
}
