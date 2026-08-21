import Foundation
import Observation
import AVFoundation

/// The chime catalog the UI talks to: built-in packs plus whatever the user imported.
@MainActor
@Observable
final class SoundLibrary {
    static let shared = SoundLibrary()
    /// `nonisolated`: the normaliser tags sounds with it off the main actor.
    nonisolated static let importedPackID = "imported"
    /// What plays until the user chooses something else, and where deleting the
    /// selected import lands.
    nonisolated static let fallbackSoundID = bundledClip?.id ?? "engines-fanfare"

    /// A clip shipped inside the app, prepared with `Tools/prepare_clip.sh`.
    /// Absent from the repo on purpose — it is someone else's recording — so the
    /// whole feature degrades to the synthesised chimes when the file is not there.
    nonisolated static let bundledClip: StartupSound? = {
        guard let url = Bundle.main.url(forResource: "startup-clip", withExtension: "m4a") else {
            return nil
        }
        // Read the real length: the clip travels whole, so it is whatever the file says.
        let duration = (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
        return StartupSound(id: "featured-clip", name: "Mi clip", packID: "featured",
                            storage: .bundle, fileName: "startup-clip.m4a", duration: duration)
    }()

    private(set) var packs: [SoundPack] = []
    /// Set while the synthesised chimes are being rendered for the first time.
    private(set) var isPreparing = false

    private init() {
        packs = buildPacks()
    }

    // MARK: - Lookup

    func sound(id: String) -> StartupSound? {
        packs.lazy.flatMap(\.sounds).first { $0.id == id }
    }

    /// The bundled clip is reachable before `packs` is built, which is what the
    /// intent needs when Shortcuts wakes the app cold.
    func soundOrBundled(id: String) -> StartupSound? {
        sound(id: id) ?? (id == Self.bundledClip?.id ? Self.bundledClip : nil)
    }

    var selected: StartupSound? {
        SharedStore.selectedSoundID.flatMap(soundOrBundled(id:))
    }

    func select(_ sound: StartupSound) {
        SharedStore.selectedSoundID = sound.id
    }

    // MARK: - Preparation

    /// Renders any chime whose file is not on disk yet. Cheap after the first run,
    /// so it is safe to call on every launch.
    func prepareIfNeeded() async {
        isPreparing = true
        defer { isPreparing = false }

        await Task.detached(priority: .utility) {
            for group in ChimeRecipes.all {
                for recipe in group.recipes {
                    do {
                        try ChimeSynth.file(for: recipe)
                    } catch {
                        NSLog("[Ignition] could not render \(recipe.id): \(error.localizedDescription)")
                    }
                }
            }
        }.value

        packs = buildPacks()
        if SharedStore.selectedSoundID == nil {
            SharedStore.selectedSoundID = Self.fallbackSoundID
        }
    }

    // MARK: - Imports

    func importSound(from url: URL, name: String,
                     start: TimeInterval = 0, length: TimeInterval? = nil) async throws {
        let sound = try await AudioNormalizer.importSound(from: url, name: name,
                                                          start: start, length: length)
        SharedStore.importedSounds.append(sound)
        packs = buildPacks()
    }

    /// Two-layer import: a lead clip over a musical bed.
    func mixSounds(foreground: URL, background: URL, backgroundGain: Float, name: String) async throws {
        let sound = try await AudioNormalizer.mixSounds(foreground: foreground,
                                                        background: background,
                                                        backgroundGain: backgroundGain,
                                                        name: name)
        SharedStore.importedSounds.append(sound)
        packs = buildPacks()
    }

    func deleteImported(_ sound: StartupSound) {
        if let url = sound.url { try? FileManager.default.removeItem(at: url) }
        SharedStore.importedSounds.removeAll { $0.id == sound.id }
        if SharedStore.selectedSoundID == sound.id {
            SharedStore.selectedSoundID = Self.fallbackSoundID
        }
        packs = buildPacks()
    }

    // MARK: - Building

    private func buildPacks() -> [SoundPack] {
        var result: [SoundPack] = []
        if let clip = Self.bundledClip {
            result.append(SoundPack(id: "featured", name: "Destacado",
                                    subtitle: "El clip que traes de casa",
                                    symbol: "star.fill", sounds: [clip]))
        }
        result += ChimeRecipes.all.map { group in
            SoundPack(
                id: group.pack,
                name: group.name,
                subtitle: group.subtitle,
                symbol: group.symbol,
                sounds: group.recipes.map { recipe in
                    StartupSound(id: recipe.id, name: recipe.name, packID: recipe.packID,
                                 storage: .container, fileName: "\(recipe.id).wav",
                                 duration: recipe.duration)
                }
            )
        }
        let imported = SharedStore.importedSounds
        if !imported.isEmpty {
            result.append(SoundPack(id: Self.importedPackID, name: "Mis sonidos",
                                    subtitle: "Audio que has importado",
                                    symbol: "square.and.arrow.down.fill", sounds: imported))
        }
        return result
    }
}
