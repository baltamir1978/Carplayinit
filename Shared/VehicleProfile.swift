import Foundation

/// How the paint reflects — matte skips the specular highlight in the artwork.
enum PaintFinish: String, Codable, CaseIterable, Identifiable {
    case gloss, matte, satin

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .gloss: return "Brillo"
        case .matte: return "Mate"
        case .satin: return "Satinado"
        }
    }
}

/// A car the user has added to their garage.
struct VehicleProfile: Identifiable, Codable, Hashable {
    static let defaultPlateCountry = "E"

    var id: UUID = UUID()
    var brandID: String
    var model: String
    var year: Int?
    /// Free-form name shown on the widget ("El coche de Bruno"). Empty means "use the model".
    var nickname: String = ""
    var plate: String = ""
    /// Country code on the plate's blue band. Optional so a garage saved before
    /// this field existed still decodes — a missing key on a non-optional
    /// property makes the synthesised decoder throw, and the whole garage with it.
    var plateCountry: String?
    /// The car's actual paint, used by the `.bodyColor` background.
    var bodyColorHex: String = ""
    var finish: PaintFinish = .gloss
    /// File name (not a full path) of the photo inside the shared container.
    var photoFileName: String?

    var brand: Brand? { BrandCatalog.brand(id: brandID) }

    /// Falls back to the marque colour when no paint has been set.
    var paintHex: String {
        bodyColorHex.isEmpty ? (brand?.primaryHex ?? "#101820") : bodyColorHex
    }

    var displayName: String {
        nickname.isEmpty ? model : nickname
    }

    var subtitle: String {
        [brand?.name, year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    /// What the plate badge paints on its blue band.
    var plateBandCode: String {
        let code = (plateCountry ?? Self.defaultPlateCountry).trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? Self.defaultPlateCountry : String(code.prefix(3)).uppercased()
    }

    var photoURL: URL? {
        photoFileName.map { SharedStore.photosDirectory.appendingPathComponent($0) }
    }
}
