import Foundation
import Observation
import UIKit

/// The user's cars and widget designs, backed by the App Group so the widget
/// extension sees every change the moment it is made.
@MainActor
@Observable
final class Garage {
    static let shared = Garage()

    private(set) var vehicles: [VehicleProfile] = []
    private(set) var designs: [WidgetDesign] = []

    private init() {
        reload()
    }

    func reload() {
        vehicles = SharedStore.vehicles
        designs = SharedStore.designs
    }

    // MARK: - Vehicles

    func add(_ vehicle: VehicleProfile) {
        vehicles.append(vehicle)
        SharedStore.vehicles = vehicles
        // A car with no design would never reach the dashboard; give it one.
        if !designs.contains(where: { $0.vehicleID == vehicle.id }) {
            add(WidgetDesign.makeDefault(for: vehicle))
        }
    }

    func update(_ vehicle: VehicleProfile) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index] = vehicle
        SharedStore.vehicles = vehicles
        SharedStore.reloadWidgets()
    }

    func delete(_ vehicle: VehicleProfile) {
        if let url = vehicle.photoURL { try? FileManager.default.removeItem(at: url) }
        vehicles.removeAll { $0.id == vehicle.id }
        designs.removeAll { $0.vehicleID == vehicle.id }
        SharedStore.vehicles = vehicles
        SharedStore.designs = designs
    }

    /// Stores a picked photo in the shared container, downscaled — the widget gets
    /// a tight memory budget and a 12 MP original will get it killed.
    func savePhoto(_ image: UIImage, for vehicle: VehicleProfile) -> VehicleProfile {
        var updated = vehicle
        let fileName = vehicle.photoFileName ?? "\(vehicle.id.uuidString).jpg"
        let url = SharedStore.photosDirectory.appendingPathComponent(fileName)
        if let data = Self.downscaled(image, maxDimension: 900).jpegData(compressionQuality: 0.85) {
            try? data.write(to: url, options: .atomic)
            updated.photoFileName = fileName
            update(updated)
        }
        return updated
    }

    func removePhoto(from vehicle: VehicleProfile) -> VehicleProfile {
        var updated = vehicle
        if let url = vehicle.photoURL { try? FileManager.default.removeItem(at: url) }
        updated.photoFileName = nil
        update(updated)
        return updated
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Designs

    func add(_ design: WidgetDesign) {
        designs.append(design)
        SharedStore.designs = designs
    }

    func update(_ design: WidgetDesign) {
        guard let index = designs.firstIndex(where: { $0.id == design.id }) else { return }
        designs[index] = design
        SharedStore.designs = designs
    }

    func delete(_ design: WidgetDesign) {
        designs.removeAll { $0.id == design.id }
        SharedStore.designs = designs
    }

    func vehicle(for design: WidgetDesign) -> VehicleProfile? {
        vehicles.first { $0.id == design.vehicleID }
    }

    func photo(for design: WidgetDesign) -> UIImage? {
        guard let url = vehicle(for: design)?.photoURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
