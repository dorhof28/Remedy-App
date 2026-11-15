//
//  Theme.swift
//  Remedy
//
//  colors spacing corners and animation
//

import SwiftUI
import UIKit

// MARK: - Themes

// the look picked in settings colours read it every time they draw
// four palettes plus graphite, each with a light and a dark side that follows the phone
nonisolated enum AppTheme: String, CaseIterable, Identifiable {
    case remedy                 // mint and pink from the app icon
    case ocean                  // sky blue and aqua
    case sunset = "sunrise"     // coral and peach, old saved name kept
    case native                 // apple's own system colours
    case graphite               // quiet grey

    static let storageKey = "appTheme"

    // cached so colours do not read UserDefaults on every draw
    private static let cache = ThemeCache()

    // one brand color now, older saved themes all draw as remedy
    static var current: AppTheme { .remedy }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remedy: return "Remedy"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .native: return "iOS Native"
        case .graphite: return "Graphite"
        }
    }

    // every theme follows the phone now
    var colorScheme: ColorScheme? { nil }

    // the two colours on the picker swatch
    var swatch: [Color] {
        let p = palette(dark: false)
        return [Color(p.accentFill), Color(p.secondSoft)]
    }
}

// holds the picked theme and re-reads it only when settings change
nonisolated private final class ThemeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AppTheme
    private var observer: NSObjectProtocol?

    // old light and dark themes land on ocean and remedy
    private static func read() -> AppTheme {
        let raw = UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? ""
        if let theme = AppTheme(rawValue: raw) { return theme }
        return raw == "light" ? .ocean : .remedy
    }

    init() {
        stored = Self.read()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in self?.reload() }
    }

    private func reload() {
        let fresh = Self.read()
        lock.lock(); defer { lock.unlock() }
        stored = fresh
    }

    var value: AppTheme {
        lock.lock(); defer { lock.unlock() }
        return stored
    }
}

// everything one theme paints, for light or dark (the design tokens)
nonisolated struct ThemePalette {
    let bg: UIColor             // screen behind the cards
    let surface: UIColor        // cards rows sheets
    let surface2: UIColor       // fields, quote boxes, segmented controls inside a card
    let line: UIColor           // hairlines between rows
    let ink: UIColor            // main text
    let ink2: UIColor           // second line text
    let ink3: UIColor           // quiet text, still 4.5 to 1
    let accentFill: UIColor     // the one filled action per screen
    let onAccent: UIColor       // text on the accent fill
    let accentInk: UIColor      // brand colour as text, links, taken checks
    let accentSoft: UIColor     // tint behind the next thing
    let second: UIColor         // logo's second colour as a fill, warmth only
    let secondInk: UIColor      // second colour as text
    let secondSoft: UIColor     // soft second tint
    let dangerFill: UIColor     // call 911 fill
    let onDanger: UIColor
    let dangerInk: UIColor      // papers disagree, warning signs
    let dangerSoft: UIColor
    let infoInk: UIColor        // the updated note
    let infoSoft: UIColor
    let cautionFill: UIColor    // sample badge
    let onCaution: UIColor
    let cautionInk: UIColor     // stops, skipped, not on your papers
    let cautionSoft: UIColor

    // increase contrast: grey text, lines and tinted words move toward the main text colour
    var highContrast: ThemePalette {
        let toInk = { (color: UIColor, amount: CGFloat) in ThemePalette.mix(color, ink, amount) }
        return ThemePalette(bg: bg, surface: surface, surface2: toInk(surface2, 0.08), line: toInk(line, 0.3),
                            ink: ink, ink2: toInk(ink2, 0.5), ink3: toInk(ink3, 0.5),
                            accentFill: toInk(accentFill, 0.2), onAccent: onAccent, accentInk: toInk(accentInk, 0.25),
                            accentSoft: accentSoft, second: second, secondInk: toInk(secondInk, 0.25), secondSoft: secondSoft,
                            dangerFill: dangerFill, onDanger: onDanger, dangerInk: toInk(dangerInk, 0.25), dangerSoft: dangerSoft,
                            infoInk: toInk(infoInk, 0.25), infoSoft: infoSoft, cautionFill: cautionFill, onCaution: onCaution,
                            cautionInk: toInk(cautionInk, 0.25), cautionSoft: cautionSoft)
    }

    // older names, so code written before the tokens still reads right
    var accent: UIColor { accentInk }
    var card: UIColor { surface }
    var edge: UIColor { line }
}

// MARK: - Grouped surfaces
// settings groups sit on a solid fill with a clear border so they never melt into the page

nonisolated extension ThemePalette {

    // a colour part of the way from one to another
    static func mix(_ a: UIColor, _ b: UIColor, _ amount: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * amount, green: ag + (bg - ag) * amount,
                       blue: ab + (bb - ab) * amount, alpha: 1)
    }

    // light cards stay as they are, dark cards lift a little off the page
    func groupFill(dark: Bool) -> UIColor {
        dark ? Self.mix(card, .white, 0.03) : card
    }

    // outline of a group, strong enough to see against the page
    func groupStroke(dark: Bool) -> UIColor {
        Self.mix(groupFill(dark: dark), dark ? .white : .black, dark ? 0.22 : 0.36)
    }

    // hairline between rows inside a group
    func groupSeparator(dark: Bool) -> UIColor {
        Self.mix(groupFill(dark: dark), dark ? .white : .black, 0.14)
    }
}

nonisolated private func hex(_ value: UInt32) -> UIColor {
    UIColor(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

// status colours are the same in every palette
nonisolated private struct StatusSet {
    let dangerFill, onDanger, dangerInk, dangerSoft, infoInk, infoSoft, cautionFill, onCaution, cautionInk, cautionSoft: UIColor

    static let light = StatusSet(dangerFill: hex(0xC4282E), onDanger: .white, dangerInk: hex(0xB3261E), dangerSoft: hex(0xFCE8E6),
                                 infoInk: hex(0x1C62C4), infoSoft: hex(0xE7F0FC), cautionFill: hex(0xF2B04A), onCaution: hex(0x3A2200),
                                 cautionInk: hex(0xA35200), cautionSoft: hex(0xFEF1E3))
    static let dark = StatusSet(dangerFill: hex(0xFF6B66), onDanger: hex(0x2B0405), dangerInk: hex(0xFF8E88), dangerSoft: hex(0x3A1514),
                                infoInk: hex(0x8CC2FF), infoSoft: hex(0x132A44), cautionFill: hex(0xF2B25A), onCaution: hex(0x2E1B00),
                                cautionInk: hex(0xFFC97A), cautionSoft: hex(0x36280F))
}

nonisolated extension AppTheme {

    // one palette from its own colours plus the shared status set
    private static func make(_ s: StatusSet, bg: UInt32, surface: UInt32, surface2: UInt32, line: UInt32,
                             ink: UInt32, ink2: UInt32, ink3: UInt32, accent: UInt32, onAccent: UInt32,
                             accentInk: UInt32, accentSoft: UInt32, second: UInt32, secondInk: UInt32,
                             secondSoft: UInt32) -> ThemePalette {
        ThemePalette(bg: hex(bg), surface: hex(surface), surface2: hex(surface2), line: hex(line),
                     ink: hex(ink), ink2: hex(ink2), ink3: hex(ink3), accentFill: hex(accent), onAccent: hex(onAccent),
                     accentInk: hex(accentInk), accentSoft: hex(accentSoft), second: hex(second),
                     secondInk: hex(secondInk), secondSoft: hex(secondSoft),
                     dangerFill: s.dangerFill, onDanger: s.onDanger, dangerInk: s.dangerInk, dangerSoft: s.dangerSoft,
                     infoInk: s.infoInk, infoSoft: s.infoSoft, cautionFill: s.cautionFill, onCaution: s.onCaution,
                     cautionInk: s.cautionInk, cautionSoft: s.cautionSoft)
    }

    // a theme's colors in light or dark mode
    func palette(dark: Bool) -> ThemePalette {
        let s = dark ? StatusSet.dark : StatusSet.light
        switch (self, dark) {
        case (.remedy, false):
            return Self.make(s, bg: 0xFDF2F5, surface: 0xFFFFFF, surface2: 0xF2F2F7, line: 0xE5E5EA,
                             ink: 0x000000, ink2: 0x5F5F64, ink3: 0x6C6C70, accent: 0x158069, onAccent: 0xFFFFFF,
                             accentInk: 0x0F6D5A, accentSoft: 0xE3F1EE, second: 0xFCC3D5, secondInk: 0xA12E58, secondSoft: 0xFDE7EE)
        case (.remedy, true):
            return Self.make(s, bg: 0x000000, surface: 0x1C1C1E, surface2: 0x2C2C2E, line: 0x38383A,
                             ink: 0xFFFFFF, ink2: 0xAEAEB2, ink3: 0x8E8E93, accent: 0x2A9D82, onAccent: 0x000000,
                             accentInk: 0x3DB596, accentSoft: 0x15322B, second: 0xF5AFC4, secondInk: 0xF7B8CB, secondSoft: 0x3A2029)
        case (.ocean, false):
            return Self.make(s, bg: 0xF3F7FB, surface: 0xFFFFFF, surface2: 0xEAF0F6, line: 0xDCE5EE,
                             ink: 0x141B22, ink2: 0x4F5B67, ink3: 0x64707C, accent: 0x6BBCF3, onAccent: 0x04223A,
                             accentInk: 0x0B5FA5, accentSoft: 0xDFEFFC, second: 0xA8E3EC, secondInk: 0x0B6575, secondSoft: 0xE2F6F9)
        case (.ocean, true):
            return Self.make(s, bg: 0x08121D, surface: 0x0F1D2B, surface2: 0x172838, line: 0x22374A,
                             ink: 0xEAF2FA, ink2: 0xA6B8CA, ink3: 0x8599AD, accent: 0x6CBDF5, onAccent: 0x03213A,
                             accentInk: 0x8ECDFF, accentSoft: 0x12304A, second: 0x7FD3E0, secondInk: 0x9BE3EE, secondSoft: 0x10323A)
        case (.sunset, false):
            return Self.make(s, bg: 0xFCF6F2, surface: 0xFFFFFF, surface2: 0xF6EDE7, line: 0xEEE1D8,
                             ink: 0x211A17, ink2: 0x5E524C, ink3: 0x74675F, accent: 0xFF9F80, onAccent: 0x3D1406,
                             accentInk: 0xAB3A15, accentSoft: 0xFFE6DC, second: 0xFFD2AE, secondInk: 0x8F4510, secondSoft: 0xFFF0E3)
        case (.sunset, true):
            return Self.make(s, bg: 0x1A110E, surface: 0x251915, surface2: 0x31231D, line: 0x3E2D26,
                             ink: 0xFBF0EA, ink2: 0xCDB6AA, ink3: 0xAE978B, accent: 0xFFA384, onAccent: 0x3A1205,
                             accentInk: 0xFFB49B, accentSoft: 0x43251B, second: 0xF5C29A, secondInk: 0xFFD2AE, secondSoft: 0x3B2A1C)
        // apple's blue, one step darker so white labels pass 4.5 to 1
        case (.native, false):
            return Self.make(s, bg: 0xF2F2F7, surface: 0xFFFFFF, surface2: 0xEEEEF0, line: 0xD1D1D6,
                             ink: 0x000000, ink2: 0x5F5F64, ink3: 0x6C6C70, accent: 0x0062CC, onAccent: 0xFFFFFF,
                             accentInk: 0x0062CC, accentSoft: 0xE5F0FF, second: 0x5856D6, secondInk: 0x5856D6, secondSoft: 0xEEEEFB)
        case (.native, true):
            return Self.make(s, bg: 0x000000, surface: 0x1C1C1E, surface2: 0x2C2C2E, line: 0x38383A,
                             ink: 0xFFFFFF, ink2: 0xAEAEB2, ink3: 0x8E8E93, accent: 0x409CFF, onAccent: 0x00152E,
                             accentInk: 0x409CFF, accentSoft: 0x0A2A4D, second: 0x5E5CE6, secondInk: 0xA5A3FF, secondSoft: 0x1F1E45)
        case (.graphite, false):
            return Self.make(s, bg: 0xF2F2F5, surface: 0xFFFFFF, surface2: 0xEBEBEF, line: 0xDADADF,
                             ink: 0x1C1C1E, ink2: 0x55555A, ink3: 0x66666B, accent: 0x2C2C2E, onAccent: 0xFFFFFF,
                             accentInk: 0x2C2C2E, accentSoft: 0xE5E5EA, second: 0xC7C7CC, secondInk: 0x48484A, secondSoft: 0xEFEFF2)
        case (.graphite, true):
            return Self.make(s, bg: 0x000000, surface: 0x1C1C1E, surface2: 0x2C2C2E, line: 0x38383A,
                             ink: 0xFFFFFF, ink2: 0xAEAEB2, ink3: 0x8E8E93, accent: 0xE5E5EA, onAccent: 0x1C1C1E,
                             accentInk: 0xE5E5EA, accentSoft: 0x2C2C2E, second: 0x636366, secondInk: 0xD1D1D6, secondSoft: 0x242426)
        }
    }

    // same as dynamic but the pick also learns if it is dark
    fileprivate static func dynamicScheme(_ pick: @escaping (ThemePalette, Bool) -> UIColor) -> UIColor {
        UIColor { (traits: UITraitCollection) -> UIColor in
            let dark = traits.userInterfaceStyle == .dark
            return pick(palette(for: traits), dark)
        }
    }

    // the palette for this moment, follows light and dark of the view it is drawn in
    fileprivate static func dynamic(_ pick: @escaping (ThemePalette) -> UIColor) -> UIColor {
        UIColor { (traits: UITraitCollection) -> UIColor in
            pick(palette(for: traits))
        }
    }

    // light or dark, then stronger when increase contrast is on
    private static func palette(for traits: UITraitCollection) -> ThemePalette {
        let base = AppTheme.current.palette(dark: traits.userInterfaceStyle == .dark)
        return traits.accessibilityContrast == .high ? base.highContrast : base
    }
}

// MARK: - Colours
// every screen reads these, so a new theme reaches all of them without changes

extension Color {

    // the design tokens
    static let ink = Color(AppTheme.dynamic { $0.ink })
    static let ink2 = Color(AppTheme.dynamic { $0.ink2 })
    static let ink3 = Color(AppTheme.dynamic { $0.ink3 })
    static let surface = Color(AppTheme.dynamic { $0.surface })
    static let surface2 = Color(AppTheme.dynamic { $0.surface2 })
    static let hairline = Color(AppTheme.dynamic { $0.line })
    static let accentFill = Color(AppTheme.dynamic { $0.accentFill })
    static let accentInk = Color(AppTheme.dynamic { $0.accentInk })
    static let accentSoft = Color(AppTheme.dynamic { $0.accentSoft })
    static let secondFill = Color(AppTheme.dynamic { $0.second })
    static let secondInk = Color(AppTheme.dynamic { $0.secondInk })
    static let secondSoft = Color(AppTheme.dynamic { $0.secondSoft })
    static let dangerFill = Color(AppTheme.dynamic { $0.dangerFill })
    static let onDanger = Color(AppTheme.dynamic { $0.onDanger })
    static let dangerInk = Color(AppTheme.dynamic { $0.dangerInk })
    static let dangerSoft = Color(AppTheme.dynamic { $0.dangerSoft })
    static let infoInk = Color(AppTheme.dynamic { $0.infoInk })
    static let infoSoft = Color(AppTheme.dynamic { $0.infoSoft })
    static let cautionFill = Color(AppTheme.dynamic { $0.cautionFill })
    static let onCaution = Color(AppTheme.dynamic { $0.onCaution })
    static let cautionInk = Color(AppTheme.dynamic { $0.cautionInk })
    static let cautionSoft = Color(AppTheme.dynamic { $0.cautionSoft })

    // brand colour as text and icons (accent ink), readable on cards
    static let remedyTeal = accentInk

    // text or icons drawn on the accent fill
    static let onAccent = Color(AppTheme.dynamic { $0.onAccent })

    // logo mint and pink, decoration only, never text
    static let logoMint = Color(UIColor(red: 0x7B / 255, green: 0xD6 / 255, blue: 0xC0 / 255, alpha: 1))

    // flat page colour (the washed page is RemedyBackground)
    static let screenBackground = Color(AppTheme.dynamic { $0.bg })

    // solid card on top of the page
    static let cardBackground = surface
    // solid fill, outline and row line of a settings group
    static let groupFill = Color(AppTheme.dynamicScheme { $0.groupFill(dark: $1) })
    static let groupStroke = Color(AppTheme.dynamicScheme { $0.groupStroke(dark: $1) })
    static let groupSeparator = Color(AppTheme.dynamicScheme { $0.groupSeparator(dark: $1) })
    // faint fill for tiles and fields inside a card
    static let tileBackground = surface2
    // grey for empty circles future days and chevrons
    static let inactive = ink3
}

// MARK: - Tone: what something MEANS (the ViewModel decides, the view colours it)

// ViewModels never pick colours
enum Tone: Equatable {
    case neutral    // plain information
    case good       // OK / taken / done
    case info       // brand: next, upcoming
    case caution    // soon / careful
    case stop       // don't take / missed / warning sign
}

extension Tone {
    var color: Color {
        switch self {
        case .neutral: return .secondary
        case .good: return .toneGreen
        case .info: return .remedyTeal
        case .caution: return .toneOrange
        case .stop: return .toneRed
        }
    }
}

// MARK: - Readable status colours
// apple's increased contrast reds greens and oranges, so status words pass 4.5 to 1 on a card

// status colors as uikit colors, used where swiftui colors cannot go
nonisolated enum StatusColors {
    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    // solid fill behind white text, the same in light and dark
    static let emergencyFill = rgb(0xC4161C)

    // a color that follows light and dark mode
    static func pick(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }
}

extension Color {
    // danger only means papers disagree, call 911 or a ticked warning sign
    static let toneRed = dangerInk
    // ok, taken and done, a darker green so text passes 4.5 to 1 on a card
    static let toneGreen = Color(StatusColors.pick(light: StatusColors.rgb(0x1E7B34), dark: StatusColors.rgb(0x30D158)))
    // soft fill behind a good icon
    static let goodSoft = Color(StatusColors.pick(light: StatusColors.rgb(0xE6F3EA), dark: StatusColors.rgb(0x16301F)))
    // stops, skipped, not on your papers
    static let toneOrange = cautionInk
    // emergency buttons and tiles, white text stays above 4.5 to 1
    static let emergencyRed = Color(StatusColors.emergencyFill)
}

extension DoseSlotState {
    // colour of the little dot / tick for a dose
    var color: Color {
        switch self {
        case .taken: return .toneGreen
        case .missed, .skipped: return .toneRed
        case .due: return .remedyTeal
        case .upcoming: return .inactive
        }
    }
}

// MARK: - Spacing

// gaps
enum Spacing {
    static let screenEdge: CGFloat = 16      // classic side margin
    static let simpleEdge: CGFloat = 20      // simple side margin
    static let betweenCards: CGFloat = 10    // gap between cards
    static let insideCard: CGFloat = 16      // padding inside a card
    static let sectionGap: CGFloat = 18      // section header below the card above it
    static let minTarget: CGFloat = 44       // HIG minimum tap size
    static let tapMin: CGFloat = 48          // content controls, for shaky hands
    static let tapSimple: CGFloat = 64       // every button and row in simple
    static let buttonHeight: CGFloat = 52    // classic buttons
    static let rowMin: CGFloat = 52          // classic list row
    static let iconTile: CGFloat = 36        // the type icon tile in a row
    static let painButton: CGFloat = 50      // a round number on the pain scale
}

// MARK: - Corner radius

// corner sizes
enum Radius {
    static let small: CGFloat = 10           // badges, icon tiles, the hidden tag
    static let tile: CGFloat = 14            // fields, quote boxes, anything inside a card
    static let card: CGFloat = 26            // cards and grouped lists
    static let large: CGFloat = 38           // sheets and simple's big cards
    // buttons are capsules, a big number keeps them round at any height
    static let button: CGFloat = 999
}

// MARK: - Motion
// rule animate only when it helps you understand a change

// animations
enum Motion {
    // the app's standard animation
    static let standard: Animation = .snappy(duration: 0.3)

    // the animation to use or nil when Reduce Motion is on
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : standard
    }

    // for view models that cannot read the environment, asks the phone
    @MainActor
    static func run(_ change: () -> Void) {
        perform(UIAccessibility.isReduceMotionEnabled, change)
    }

    // animates unless reduce motion is on
    @MainActor
    static func perform(_ reduceMotion: Bool, _ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(standard) { change() }
        }
    }
}

extension AnyTransition {
    // new content slides in from the side with Reduce Motion it just fades
    static func slideIn(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                           removal: .move(edge: .leading).combined(with: .opacity))
    }
}

// MARK: - Page background
// the plain page with a soft pink to mint wash over the top third, cards sit on it

// the page behind every screen
struct RemedyBackground: View {
    var body: some View {
        // a flat page, the brand pink in light and black in dark
        Color.screenBackground
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    // page background for a whole screen: use it where Color.screenBackground was
    func remedyBackground() -> some View {
        background { RemedyBackground() }
    }
}
