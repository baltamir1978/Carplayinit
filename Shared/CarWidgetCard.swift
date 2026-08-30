import SwiftUI
import WidgetKit

// MARK: - Brand mark

/// The marque emblem, or a monogram when no artwork is installed for it.
///
/// Artwork is optional on purpose: drop `logo-<id>` into the asset catalog and it
/// appears everywhere; remove it and the monogram takes over with no code change.
struct BrandMark: View {
    let brand: Brand?
    var size: CGFloat = 44
    var tint: Color = .white

    var body: some View {
        Group {
            if let brand, let image = BrandMark.artwork(named: brand.logoAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
    }

    private var monogram: some View {
        Text(brand?.monogram ?? "??")
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .kerning(size * 0.02)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .stroke(tint.opacity(0.75), lineWidth: max(1.5, size * 0.045))
            }
    }

    /// Looks the emblem up in whichever bundle is running (app or extension).
    static func artwork(named name: String) -> UIImage? {
        UIImage(named: name) ?? UIImage(named: name, in: .main, with: nil)
    }
}

// MARK: - Card

/// The widget artwork itself — shared by the widget extension and the in-app editor
/// preview so what you design is exactly what lands on the dashboard.
struct CarWidgetCard: View {
    let design: WidgetDesign
    let vehicle: VehicleProfile?
    let photo: UIImage?

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground

    private var brand: Brand? { vehicle?.brand }

    /// Foreground colour: honour the explicit choice, otherwise pick for contrast.
    private var foreground: Color {
        if !design.textHex.isEmpty { return Color(hex: design.textHex) }
        switch design.background {
        case .photo, .carbon: return .white
        case .solid:          return Color(hex: design.backgroundHex).readableForeground
        case .bodyColor:      return Color(hex: vehicle?.paintHex ?? "#101820").readableForeground
        case .brandGradient:  return Color(hex: brand?.primaryHex ?? "#101820").readableForeground
        }
    }

    var body: some View {
        ZStack {
            background
            content
                .padding(14)
        }
        // CarPlay and StandBy strip the container background, so we round our own
        // artwork; on the Home Screen the system clip already matches.
        .clipShape(RoundedRectangle(cornerRadius: showsContainerBackground ? 0 : design.cornerRadius,
                                    style: .continuous))
    }

    // MARK: Background

    @ViewBuilder
    private var background: some View {
        switch design.background {
        case .brandGradient:
            LinearGradient(
                colors: [Color(hex: brand?.primaryHex ?? "#1B2A33"),
                         Color(hex: brand?.secondaryHex ?? "#101820")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .solid:
            Color(hex: design.backgroundHex)
        case .carbon:
            CarbonWeave()
        case .bodyColor:
            PaintFinishBackground(hex: vehicle?.paintHex ?? "#101820",
                                  finish: vehicle?.finish ?? .gloss)
        case .photo:
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(design.photoDim))
            } else {
                LinearGradient(
                    colors: [Color(hex: brand?.primaryHex ?? "#1B2A33"), .black],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private var content: some View {
        switch design.layout {
        case .badge:   badgeLayout
        case .photo:   photoLayout
        case .plate:   plateLayout
        case .minimal: minimalLayout
        }
    }

    private var badgeLayout: some View {
        VStack(spacing: 8) {
            if design.showsLogo {
                BrandMark(brand: brand, size: 52, tint: foreground)
            }
            Text(vehicle?.displayName ?? "Mi coche")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if design.showsModel, let brand {
                Text(brand.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.4)
                    .opacity(0.75)
            }
            if design.showsClock { clock.padding(.top, 2) }
        }
        .foregroundStyle(foreground)
    }

    private var photoLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            if design.showsLogo {
                BrandMark(brand: brand, size: 30, tint: foreground)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
            Text(vehicle?.displayName ?? "Mi coche")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if design.showsModel {
                Text(vehicle?.subtitle ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.85)
                    .lineLimit(1)
            }
            if design.showsPlate, let plate = vehicle?.plate, !plate.isEmpty {
                PlateBadge(text: plate, compact: true,
                           country: vehicle?.plateBandCode ?? VehicleProfile.defaultPlateCountry)
                    .padding(.top, 4)
            }
            if design.showsClock { clock }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .foregroundStyle(foreground)
        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
    }

    private var plateLayout: some View {
        VStack(spacing: 10) {
            if design.showsLogo {
                BrandMark(brand: brand, size: 34, tint: foreground)
            }
            PlateBadge(text: vehicle?.plate.isEmpty == false ? vehicle!.plate : "0000 XXX",
                       compact: false,
                       country: vehicle?.plateBandCode ?? VehicleProfile.defaultPlateCountry)
            if design.showsModel {
                Text(vehicle?.subtitle ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.8)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(foreground)
    }

    private var minimalLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                if design.showsLogo { BrandMark(brand: brand, size: 26, tint: foreground) }
                Text(brand?.name.uppercased() ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.2)
                    .opacity(0.75)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(vehicle?.displayName ?? "Mi coche")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            if design.showsClock { clock }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(foreground)
    }

    /// A live clock costs no timeline entries — `.timer`/`.date` styles update themselves.
    private var clock: some View {
        Text(Date(), style: .time)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .opacity(0.85)
            .monospacedDigit()
    }
}

// MARK: - Pieces

/// European-style plate: blue EU band on the left, characters on white.
struct PlateBadge: View {
    let text: String
    var compact: Bool
    /// Country letters on the band. Spain by default, editable per car.
    var country: String = VehicleProfile.defaultPlateCountry

    private var height: CGFloat { compact ? 22 : 34 }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 1) {
                Text("★").font(.system(size: height * 0.22)).opacity(0.9)
                Text(country)
                    .font(.system(size: height * 0.3, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: height * 0.42, height: height)
            .background(Color(hex: "#003399"))

            Text(text.uppercased())
                .font(.system(size: height * 0.52, weight: .bold, design: .rounded))
                .kerning(height * 0.03)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, height * 0.2)
                .frame(height: height)
                .background(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: height * 0.16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: height * 0.16, style: .continuous)
                .stroke(.black.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Carbon-fibre weave drawn with a Canvas — no bitmap to ship, sharp at any size.
struct CarbonWeave: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#15171A")))
            let cell: CGFloat = 9
            var row = 0
            var y: CGFloat = 0
            while y < size.height {
                var col = 0
                var x: CGFloat = 0
                while x < size.width {
                    let dark = (row + col).isMultiple(of: 2)
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    context.fill(Path(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6), cornerRadius: 1.5),
                                 with: .color(dark ? Color(hex: "#23262B") : Color(hex: "#191C20")))
                    x += cell
                    col += 1
                }
                y += cell
                row += 1
            }
        }
        .overlay(
            LinearGradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}


/// The car's paint as a background. Matte paint has no specular highlight — that
/// absence is most of what makes it read as matte, so the finishes differ only in
/// the sheen layer.
struct PaintFinishBackground: View {
    let hex: String
    let finish: PaintFinish

    var body: some View {
        let base = Color(hex: hex)
        ZStack {
            base
            switch finish {
            case .gloss:
                LinearGradient(colors: [.white.opacity(0.45), .clear, .black.opacity(0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.white.opacity(0.30), .clear],
                               center: .init(x: 0.25, y: 0.12), startRadius: 2, endRadius: 110)
            case .satin:
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.28)],
                               startPoint: .top, endPoint: .bottom)
            case .matte:
                // A flat wash plus a whisper of noise: matte paint scatters light
                // evenly, which on screen reads as texture, not shine.
                LinearGradient(colors: [.white.opacity(0.05), .black.opacity(0.18)],
                               startPoint: .top, endPoint: .bottom)
                MatteGrain()
            }
        }
    }
}

/// Fixed-pattern grain — deterministic so the widget never flickers between reloads.
struct MatteGrain: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x5EED
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double((seed >> 33) % 1000) / 1000
            }
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let x = next() * size.width
                let y = next() * size.height
                let alpha = 0.04 + next() * 0.05
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)),
                             with: .color(.white.opacity(alpha)))
            }
        }
        .blendMode(.overlay)
    }
}
