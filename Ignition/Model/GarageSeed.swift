import Foundation

/// The three cars this build is actually for. Installed once, on an empty garage,
/// so a fresh install already has something on the dashboard; everything here is
/// editable afterwards and never re-applied.
enum GarageSeed {
    private static let installedKey = "garage_seed_installed"

    static func installIfNeeded() {
        // Two guards on purpose: the flag means "already done once", the emptiness
        // check means "do not stomp on anything". Deleting the three cars has to
        // stick, so an empty garage is not on its own a reason to re-seed.
        guard !UserDefaults.standard.bool(forKey: installedKey),
              SharedStore.vehicles.isEmpty else { return }
        defer { UserDefaults.standard.set(true, forKey: installedKey) }

        let defender = VehicleProfile(
            brandID: "landrover",
            model: "Defender 110",
            year: 2024,
            bodyColorHex: "#3E4A3B",   // verde mate
            finish: .matte
        )
        let dolphin = VehicleProfile(
            brandID: "byd",
            model: "Dolphin",
            year: 2024,
            bodyColorHex: "#8C9195",   // gris
            finish: .gloss
        )
        let t03 = VehicleProfile(
            brandID: "leapmotor",
            model: "T03",
            year: 2024,
            bodyColorHex: "#A9CDE6",   // azul claro
            finish: .gloss
        )

        let vehicles = [defender, dolphin, t03]
        SharedStore.vehicles = vehicles

        // A design per car, using the paint rather than the marque gradient — with
        // three specific cars, the paint *is* the identity.
        SharedStore.designs = vehicles.map { vehicle in
            var design = WidgetDesign.makeDefault(for: vehicle)
            design.background = .bodyColor
            design.layout = .badge
            design.name = "\(vehicle.brand?.name ?? "") \(vehicle.model)"
            return design
        }
    }
}
