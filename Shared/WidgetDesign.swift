import Foundation

/// How the car widget arranges its content.
///
/// CarPlay renders widgets as `systemSmall` in StandBy style: full colour, no
/// container background, big type. Every layout here is designed for that first
/// and reused as-is on the Home Screen.
enum WidgetLayout: String, Codable, CaseIterable, Identifiable {
    case badge      // Logo (or monogram) over the marque gradient.
    case photo      // The user's own photo, edge to edge, with a text overlay.
    case plate      // European licence plate, model underneath.
    case minimal    // Small mark, name and clock — the most glanceable one.

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .badge:   return "Emblema"
        case .photo:   return "Foto"
        case .plate:   return "Matrícula"
        case .minimal: return "Mínimo"
        }
    }
}

/// Background treatment behind the layout.
enum BackgroundKind: String, Codable, CaseIterable, Identifiable {
    case brandGradient  // Diagonal gradient from the marque's primary/secondary.
    case solid          // Flat `backgroundHex`.
    case photo          // The vehicle photo, dimmed by `photoDim`.
    case carbon         // Dark carbon-fibre weave, drawn in code.
    case bodyColor      // The car's own paint, with its finish.

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .brandGradient: return "Degradado de marca"
        case .solid:         return "Color sólido"
        case .photo:         return "Foto del coche"
        case .carbon:        return "Fibra de carbono"
        case .bodyColor:     return "Color del coche"
        }
    }
}

/// A saved widget design. The widget extension reads these through the App Group;
/// the configuration intent picks one by `id`.
struct WidgetDesign: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var vehicleID: UUID?
    var layout: WidgetLayout = .badge
    var background: BackgroundKind = .brandGradient
    /// Used when `background == .solid`.
    var backgroundHex: String = "#101820"
    /// Text/foreground colour. Empty means "derive from the background".
    var textHex: String = ""
    /// 0…1 — how much the photo is darkened so text stays legible in the car.
    var photoDim: Double = 0.45
    var showsLogo: Bool = true
    var showsModel: Bool = true
    var showsPlate: Bool = false
    var showsClock: Bool = false
    /// Rounds the artwork *inside* the widget; CarPlay clips the widget itself.
    var cornerRadius: Double = 22

    static func makeDefault(for vehicle: VehicleProfile) -> WidgetDesign {
        WidgetDesign(
            name: vehicle.displayName,
            vehicleID: vehicle.id,
            layout: vehicle.photoFileName == nil ? .badge : .photo,
            background: vehicle.photoFileName == nil ? .brandGradient : .photo
        )
    }
}
