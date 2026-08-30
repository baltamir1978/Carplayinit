import SwiftUI
import AVFoundation

/// Writes a startup sound by typing it: the phone says the text and it lands in the
/// list like any other chime.
struct SpeechSoundView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var library = SoundLibrary.shared

    @State private var text = "Enciende motores"
    @State private var kind: SpeechSynth.VoiceKind = .masculine
    @State private var rate: Double = Double(SpeechSynth.VoiceKind.masculine.defaultRate)
    @State private var isSaving = false
    @State private var error: String?
    @State private var previewer = AVSpeechSynthesizer()
    /// "" = automática. Guardado por voz, así que cada una recuerda la suya.
    @State private var voiceID: String = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Lo que quieres que diga", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Texto")
                } footer: {
                    Text("Se dirá tal cual. Las comas y los puntos marcan las pausas, así que úsalos: «Buenos días, Bruno.» suena mejor que sin ellos.")
                }

                Section {
                    Picker("Voz", selection: $kind) {
                        ForEach(SpeechSynth.VoiceKind.allCases) { kind in
                            Label(kind.localizedName, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newValue in
                        // Cada voz trae su propia velocidad: es la mitad de su carácter.
                        stopPreview()
                        rate = Double(newValue.defaultRate)
                        voiceID = SpeechSynth.preferredIdentifier(for: newValue) ?? ""
                    }

                    Text(kind.character)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Cuál", selection: $voiceID) {
                        Text("Automática").tag("")
                        ForEach(SpeechSynth.spanishVoices(), id: \.identifier) { voice in
                            Text(SpeechSynth.describe(voice)).tag(voice.identifier)
                        }
                    }
                    .onChange(of: voiceID) { _, newValue in
                        stopPreview()
                        SpeechSynth.setPreferredIdentifier(newValue.isEmpty ? nil : newValue, for: kind)
                    }

                    if let sonando = SpeechSynth.voice(for: kind) {
                        LabeledContent("Suena", value: SpeechSynth.describe(sonando))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Velocidad") {
                        Slider(value: $rate,
                               in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate))
                    }

                    Button(previewer.isSpeaking ? "Parar" : "Escuchar",
                           systemImage: previewer.isSpeaking ? "stop.circle" : "play.circle") {
                        previewer.isSpeaking ? stopPreview() : preview()
                    }
                    .disabled(trimmed.isEmpty)
                } header: {
                    Text("Voz")
                } footer: {
                    if SpeechSynth.isSubstituting(kind) {
                        Text("Tu iPhone no tiene instalada ninguna voz \(kind.localizedName.lowercased()) en español, así que suena la que hay con el tono forzado — y se nota. Instálala en Ajustes → Accesibilidad → Contenido hablado → Voces → Español: Jorge o Álvaro para la masculina, Mónica o Marisol para la femenina.")
                    } else {
                        Text("Las voces de serie suenan a robot. En Ajustes → Accesibilidad → Contenido hablado → Voces → Español puedes descargar las «Mejorada» o «Premium», que son otra cosa.")
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            HStack { ProgressView(); Text("Creando…") }
                        } else {
                            Text("Guardar como sonido")
                        }
                    }
                    .disabled(trimmed.isEmpty || isSaving)
                } footer: {
                    Text("Se nivela a −12 dBFS como el resto. Después, toca su círculo en la lista para dejarlo como sonido de arranque.")
                }
            }
            .navigationTitle("Texto a voz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task { voiceID = SpeechSynth.preferredIdentifier(for: kind) ?? "" }
            .onDisappear(perform: stopPreview)
            .alert("No se pudo crear", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) {
                Button("Vale", role: .cancel) {}
            } message: {
                Text(error ?? "")
            }
        }
    }

    // MARK: - Actions

    private func preview() {
        // `.playback` so the preview is audible with the ring switch on silent —
        // the same reason the player uses it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                         options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        previewer.speak(SpeechSynth.utterance(text: trimmed, kind: kind, rate: Float(rate)))
    }

    private func stopPreview() {
        previewer.stopSpeaking(at: .immediate)
    }

    private func save() {
        stopPreview()
        isSaving = true
        Task {
            do {
                try await library.makeSpokenSound(text: trimmed, kind: kind, rate: Float(rate))
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}
