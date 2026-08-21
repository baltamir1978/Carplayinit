import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline

struct CarEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    let vehicle: VehicleProfile?
    let photo: UIImage?

    static let placeholder = CarEntry(
        date: Date(),
        design: WidgetDesign(name: "Mi coche", layout: .badge, background: .brandGradient),
        vehicle: VehicleProfile(brandID: "bmw", model: "Serie 3", year: 2021),
        photo: nil
    )
}

struct CarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CarEntry { .placeholder }

    func snapshot(for configuration: SelectDesignIntent, in context: Context) async -> CarEntry {
        entry(for: configuration)
    }

    /// The artwork is static, so one entry with `.never` is enough — the clock
    /// variants refresh themselves through `Text(style:)` without a reload.
    func timeline(for configuration: SelectDesignIntent, in context: Context) async -> Timeline<CarEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectDesignIntent) -> CarEntry {
        guard let design = SharedStore.design(id: configuration.design?.id) else {
            return .placeholder
        }
        let vehicle = SharedStore.vehicle(id: design.vehicleID)
        var photo: UIImage?
        if design.background == .photo, let url = vehicle?.photoURL {
            photo = UIImage(contentsOfFile: url.path)
        }
        return CarEntry(date: Date(), design: design, vehicle: vehicle, photo: photo)
    }
}

// MARK: - Widget

struct CarWidget: Widget {
    let kind = "CarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectDesignIntent.self, provider: CarProvider()) { entry in
            CarWidgetCard(design: entry.design, vehicle: entry.vehicle, photo: entry.photo)
                // The design paints its own background edge to edge, in the car
                // and on the Home Screen alike.
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Mi coche")
        .description("El emblema, la foto y la matrícula de tu coche en el salpicadero.")
        // CarPlay renders `systemSmall` in StandBy style; the same view covers both.
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    CarWidget()
} timeline: {
    CarEntry.placeholder
}
