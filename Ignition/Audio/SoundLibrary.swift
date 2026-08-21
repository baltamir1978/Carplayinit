import Foundation
import Observation

/// The chime catalog the UI talks to: built-in packs plus whatever the user imported.
@MainActor
@Observable
final class SoundLibrary {
    static let shared = SoundLibrary()
    static let importedPackID = "imported"

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

    var selected: StartupSound? {
        SharedStore.selectedSoundID.flatMap(sound(id:))
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
            SharedStore.selectedSoundID = ChimeRecipes.classic.first?.id
        }
    }

    // MARK: - Imports

    func importSound(from url: URL, name: String) async throws {
        let sound = try await AudioNormalizer.importSound(from: url, name: name)
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
            SharedStore.selectedSoundID = ChimeRecipes.classic.first?.id
        }
        packs = buildPacks()
    }

    // MARK: - Building

    private func buildPacks() -> [SoundPack] {
        var result = ChimeRecipes.all.map { group in
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
