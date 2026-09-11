import SwiftUI
import UIKit

/// One selectable app icon. `assetName` is the appiconset's name and what
/// `setAlternateIconName` takes; `nil` is the primary icon.
struct AppIconOption: Identifiable, Hashable {
    var assetName: String?
    var title: String
    /// Gradient for the picker tile when the compiled icon cannot be
    /// loaded (the simulator, a build without the asset).
    var topHex: String
    var bottomHex: String
    var glyph: String = "graduationcap.fill"
    var glyphHex: String = "#ffffff"

    var id: String { assetName ?? "primary" }
}

/// A pack is what is sold: one product, several icons. A pack without a
/// product is free.
struct AppIconPack: Identifiable {
    var id: String
    var title: String
    var footer: String
    var productID: ProductID?
    var icons: [AppIconOption]
}

/// Every icon the app ships. Alternate icons must be *bundled* — iOS cannot
/// download them — so the list is code, mirrored 1:1 by the asset catalog
/// and `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.yml`.
enum AppIconCatalog {
    static let primary = AppIconOption(assetName: nil, title: "Klassisch", topHex: "#4d8bff", bottomHex: "#1f3fb8", glyph: "bag.fill")

    static let classic = AppIconPack(
        id: "classic",
        title: "Klassisch",
        footer: "Sechs Farben, ein Symbol.",
        productID: .iconsClassic,
        icons: [
            AppIconOption(assetName: "AppIconMitternacht", title: "Mitternacht", topHex: "#2a2a5e", bottomHex: "#0b0b1e", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconMinze", title: "Minze", topHex: "#34d3bd", bottomHex: "#0d6e66", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconLila", title: "Lila", topHex: "#b06cf7", bottomHex: "#5b21b6", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconAbendrot", title: "Abendrot", topHex: "#fb923c", bottomHex: "#be185d", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconMono", title: "Mono", topHex: "#fafafa", bottomHex: "#e5e5ea", glyph: "bag.fill", glyphHex: "#1c1c1e"),
            AppIconOption(assetName: "AppIconNotizbuch", title: "Notizbuch", topHex: "#fdf6e3", bottomHex: "#f3e9c9", glyph: "bag.fill", glyphHex: "#1f3a6e")
        ])

    static let styles1 = AppIconPack(
        id: "styles1",
        title: "Stile I",
        footer: "Acht Stile, ein Ranzen.",
        productID: .iconsStyles1,
        icons: [
            AppIconOption(assetName: "AppIconComic", title: "Comic", topHex: "#ffd60a", bottomHex: "#ff6b1a", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconManga", title: "Manga", topHex: "#ffb8d9", bottomHex: "#a78bfa", glyph: "bag.fill"),
            AppIconOption(assetName: "AppIconPixel", title: "Pixel", topHex: "#1b1f3a", bottomHex: "#1b1f3a", glyph: "bag.fill", glyphHex: "#5ef2c8"),
            AppIconOption(assetName: "AppIconNeon", title: "Neon", topHex: "#1a0b2e", bottomHex: "#05030a", glyph: "bag", glyphHex: "#3df2ff"),
            AppIconOption(assetName: "AppIconKawaii", title: "Kawaii", topHex: "#c9f7ea", bottomHex: "#a3e9d4", glyph: "bag.fill", glyphHex: "#ff8fab"),
            AppIconOption(assetName: "AppIconGraffiti", title: "Graffiti", topHex: "#6b6f76", bottomHex: "#3b3e44", glyph: "bag.fill", glyphHex: "#ff3d81"),
            AppIconOption(assetName: "AppIconHandheld", title: "Handheld", topHex: "#9bbc0f", bottomHex: "#9bbc0f", glyph: "bag.fill", glyphHex: "#0f380f"),
            AppIconOption(assetName: "AppIconHolo", title: "Holo", topHex: "#ffd1f5", bottomHex: "#b8ffe6", glyph: "bag.fill")
        ])

    static let styles2 = AppIconPack(
        id: "styles2",
        title: "Stile II",
        footer: "Sechs-Sieben, Heldencomic, Farbe, Musik, Kreide.",
        productID: .iconsStyles2,
        icons: [
            AppIconOption(assetName: "AppIconSechsSieben", title: "Sechs-Sieben", topHex: "#d9ff3d", bottomHex: "#7ee62e", glyph: "bag.fill", glyphHex: "#101418"),
            AppIconOption(assetName: "AppIconHeldencomic", title: "Heldencomic", topHex: "#ff9f0a", bottomHex: "#e0202a", glyph: "bag.fill", glyphHex: "#2b5cff"),
            AppIconOption(assetName: "AppIconFarbe", title: "Farbe", topHex: "#fffaf0", bottomHex: "#fffaf0", glyph: "paintpalette.fill", glyphHex: "#2b2b2b"),
            AppIconOption(assetName: "AppIconGeigenkasten", title: "Geigenkasten", topHex: "#6b1e3a", bottomHex: "#2b0a17", glyph: "music.note", glyphHex: "#e0b070"),
            AppIconOption(assetName: "AppIconNoten", title: "Noten", topHex: "#7c3aed", bottomHex: "#3b1a7a", glyph: "music.note.list"),
            AppIconOption(assetName: "AppIconKreide", title: "Kreide", topHex: "#2f5d46", bottomHex: "#2f5d46", glyph: "bag")
        ])

    static let seasonal = AppIconPack(
        id: "seasonal",
        title: "Saison",
        footer: "Jedes Jahr kommt eines dazu — wer das Paket hat, bekommt sie alle.",
        productID: .iconsSeasonal,
        icons: [
            AppIconOption(assetName: "AppIconWeihnachten", title: "Weihnachten", topHex: "#1f7a3e", bottomHex: "#052e16", glyph: "snowflake"),
            AppIconOption(assetName: "AppIconSommer", title: "Sommerferien", topHex: "#fde047", bottomHex: "#f59e0b", glyph: "sun.max.fill")
        ])

    /// The thank-you for a tip. Not for sale.
    static let supporter = AppIconOption(assetName: "AppIconUnterstuetzer", title: "Unterstützer", topHex: "#f43f5e", bottomHex: "#9f1239", glyph: "heart.fill")

    static let paidPacks: [AppIconPack] = [classic, styles1, styles2, seasonal]

    /// The school's own icon from the registry, if its entry carries one.
    /// Eli's is an own design in the school colours, not the crest; a real
    /// crest gets in only with the school's written consent (see
    /// `Docs/SCHULLOGO-EINWILLIGUNG.md`).
    static func schoolIcon(for config: SchoolConfig?, schoolName: String) -> AppIconOption? {
        guard let assetName = config?.iconName else { return nil }
        let title = config?.name ?? (schoolName.isEmpty ? "Meine Schule" : schoolName)
        return AppIconOption(assetName: assetName, title: title, topHex: "#CE4B51", bottomHex: "#9E0C10", glyph: "building.columns.fill")
    }
}

/// The tile in the picker: the compiled icon when the bundle has it,
/// otherwise a drawn stand-in from the option's colours.
struct AppIconTile: View {
    let option: AppIconOption
    var size: CGFloat = 60

    var body: some View {
        Group {
            if let image = Self.bundledImage(for: option) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color(hex: option.topHex), Color(hex: option.bottomHex)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: option.glyph)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Color(hex: option.glyphHex))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.22))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    /// The asset catalog compiles alternate icons into `<Name>60x60@2x.png`
    /// and friends; `UIImage(named:)` finds them by the base name plus size.
    private static func bundledImage(for option: AppIconOption) -> UIImage? {
        let base = option.assetName ?? "AppIcon"
        for candidate in ["\(base)60x60", "\(base)76x76", base] {
            if let image = UIImage(named: candidate) { return image }
        }
        return nil
    }
}
