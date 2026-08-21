import AppIntents
import AVFoundation

/// Plays the selected chime. This is the Shortcuts half of the hybrid approach:
/// the user wires it to the "CarPlay connects" automation trigger, which fires even
/// when the app is not running — the case the in-app watcher cannot cover.
struct PlayStartupSoundIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Reproducir sonido de arranque"
    static let description = IntentDescription(
        "Reproduce el sonido de arranque elegido en Ignition. Úsalo en una automatización «Al conectar CarPlay»."
    )
    /// Audio intents must not bounce to the app — that would steal focus in the car.
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Sonido", description: "Déjalo vacío para usar el sonido elegido en la app.")
    var sound: SoundEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        let library = SoundLibrary.shared
        await library.prepareIfNeeded()

        let chime: StartupSound?
        if let id = sound?.id {
            chime = library.soundOrBundled(id: id)
        } else {
            chime = library.selected
        }
        guard let chime else { return .result() }

        StartupSoundPlayer.shared.play(chime)
        // Hold the intent alive while the clip plays; Shortcuts tears the process
        // down as soon as `perform` returns.
        try? await Task.sleep(for: .seconds(min(chime.duration + 0.4, 11)))
        return .result()
    }
}

/// One chime, for the Shortcuts parameter picker.
struct SoundEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    var packName: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Sonido de arranque")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(packName)")
    }

    static let defaultQuery = SoundQuery()
}

struct SoundQuery: EntityQuery {
    @MainActor
    private func all() -> [SoundEntity] {
        SoundLibrary.shared.packs.flatMap { pack in
            pack.sounds.map { SoundEntity(id: $0.id, name: $0.name, packName: pack.name) }
        }
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [SoundEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SoundEntity] { all() }
}

/// Ready-made shortcut so the automation can be built in two taps.
struct IgnitionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayStartupSoundIntent(),
            phrases: [
                "Reproduce el sonido de arranque de \(.applicationName)",
                "Sonido de coche con \(.applicationName)"
            ],
            shortTitle: "Sonido de arranque",
            systemImageName: "car.fill"
        )
    }
}
