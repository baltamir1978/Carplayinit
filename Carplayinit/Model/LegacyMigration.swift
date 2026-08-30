import Foundation

/// Brings across whatever the build that was called *Ignition* left behind.
///
/// Renaming the app changed the App Group, and for iOS a different group is a
/// different container: the garage, the photos and the imported chimes all stayed
/// in the old one. The app declares both groups in its entitlements for this and
/// nothing else — once the copy is done the old container is never touched again.
///
/// Everything here is best-effort on purpose. No old container (a clean install, a
/// user who never had Ignition, an entitlement the profile does not carry) simply
/// means there is nothing to bring, so it marks itself done and gets out of the way.
enum LegacyMigration {
    private static let legacySuiteName = "group.Altamirano.Ignition"
    private static let doneKey = "legacy_migration_done"

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        // Marked done even when there was nothing to do: this is a one-shot, not a
        // retry loop on every launch.
        defer { UserDefaults.standard.set(true, forKey: doneKey) }

        // A garage that already has cars is the user's, not ours to overwrite.
        guard SharedStore.vehicles.isEmpty,
              let defaults = SharedStore.defaults,
              let legacy = UserDefaults(suiteName: legacySuiteName) else { return }

        // Copied wholesale rather than key by key: the store owns its own key
        // names, and anything Apple puts in a suite is filtered out here.
        var copiedKeys = 0
        for (key, value) in legacy.dictionaryRepresentation() {
            guard !key.hasPrefix("Apple"), !key.hasPrefix("NS"), !key.hasPrefix("com.apple") else { continue }
            guard defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
            copiedKeys += 1
        }

        let files = copyContainerFiles()
        if copiedKeys > 0 || files > 0 {
            NSLog("[Carplayinit] migración desde Ignition: \(copiedKeys) ajustes, \(files) archivos")
            SharedStore.reloadWidgets()
        }
    }

    /// Photos and sounds live in the container, not in `UserDefaults`, so they are
    /// copied by hand. Existing files win — the new container is the destination,
    /// never the loser.
    private static func copyContainerFiles() -> Int {
        let manager = FileManager.default
        guard let legacyContainer = manager
            .containerURL(forSecurityApplicationGroupIdentifier: legacySuiteName) else { return 0 }

        var copied = 0
        for (name, destination) in [("Photos", SharedStore.photosDirectory),
                                    ("Sounds", SharedStore.soundsDirectory)] {
            let source = legacyContainer.appendingPathComponent(name, isDirectory: true)
            guard let entries = try? manager.contentsOfDirectory(at: source,
                                                                 includingPropertiesForKeys: nil) else { continue }
            for entry in entries {
                let target = destination.appendingPathComponent(entry.lastPathComponent)
                guard !manager.fileExists(atPath: target.path) else { continue }
                if (try? manager.copyItem(at: entry, to: target)) != nil { copied += 1 }
            }
        }
        return copied
    }
}
