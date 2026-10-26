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
nonisolated enum AppTheme: String, CaseIterable, Identifiable {
    case remedy     // mint and pink from the app icon follows the phone
    case light      // plain and bright always light
    case dark       // deep green black always dark
    case sunrise    // warm coral and peach follows the phone

    static let storageKey = "appTheme"

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .remedy
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remedy: return "Remedy"
        case .light: return "Light"
        case .dark: return "Dark"
        case .sunrise: return "Sunrise"
        }
    }

    // nil follows the phone
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .remedy, .sunrise: return nil
        }
    }

    // the two colours on the picker swatch
    var swatch: [Color] {
        switch self {
        case .remedy: return [Color(red: 0.48, green: 0.84, blue: 0.75), Color(red: 0.99, green: 0.76, blue: 0.84)]
        case .light: return [Color(red: 0.08, green: 0.50, blue: 0.41), Color(white: 0.95)]
        case .dark: return [Color(red: 0.16, green: 0.62, blue: 0.51), Color(red: 0.04, green: 0.08, blue: 0.07)]
        case .sunrise: return [Color(red: 0.85, green: 0.39, blue: 0.23), Color(red: 1.0, green: 0.90, blue: 0.80)]
        }
    }
}

// MARK: - Colours

extension Color {

    // brand colour - darker than the logo so white text stays readable
    static let remedyTeal = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        let dark = traits.userInterfaceStyle == .dark
        if AppTheme.current == .sunrise {
            return dark ? UIColor(red: 0.94, green: 0.54, blue: 0.36, alpha: 1)     // #F08A5D
                        : UIColor(red: 0.80, green: 0.36, blue: 0.20, alpha: 1)     // #CC5C33
        }
        return dark ? UIColor(red: 0.16, green: 0.62, blue: 0.51, alpha: 1)         // #2A9D82
                    : UIColor(red: 0.08, green: 0.50, blue: 0.41, alpha: 1)         // #158069
    })

    // logo mint and pink for brand touches not text
    static let logoMint = Color(red: 0.48, green: 0.84, blue: 0.75)        // #7BD6C0
    static let logoPink = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.35, green: 0.18, blue: 0.24, alpha: 1)   // #5A2E3D
        }
        return UIColor(red: 0.99, green: 0.76, blue: 0.84, alpha: 1)       // #FCC3D5
    })

    // page behind the cards
    static let screenBackground = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        let dark = traits.userInterfaceStyle == .dark
        switch AppTheme.current {
        case .remedy:
            return dark ? .systemGroupedBackground : UIColor(red: 1.0, green: 0.95, blue: 0.97, alpha: 1)    // #FFF2F7
        case .light:
            return .systemGroupedBackground
        case .dark:
            return UIColor(red: 0.03, green: 0.07, blue: 0.06, alpha: 1)                                   // #08120F
        case .sunrise:
            return dark ? UIColor(red: 0.10, green: 0.07, blue: 0.05, alpha: 1)                            // #1A120D
                        : UIColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1)                             // #FFF5EB
        }
    })

    // card on top of the page
    static let cardBackground = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        if AppTheme.current == .dark {
            return UIColor(red: 0.08, green: 0.14, blue: 0.12, alpha: 1)                                   // #14231F
        }
        return .secondarySystemGroupedBackground
    })
    // faint fill for tiles inside a card
    static let tileBackground = Color(UIColor.tertiarySystemFill)
    // grey for empty circles future days and chevrons
    static let inactive = Color(UIColor.tertiaryLabel)
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
        case .good: return .green
        case .info: return .remedyTeal
        case .caution: return .orange
        case .stop: return .red
        }
    }
}

extension DoseSlotState {
    // colour of the little dot / tick for a dose
    var color: Color {
        switch self {
        case .taken: return .green
        case .missed, .skipped: return .red
        case .due: return .remedyTeal
        case .upcoming: return .inactive
        }
    }
}

// MARK: - Spacing

// gaps
enum Spacing {
    static let screenEdge: CGFloat = 16      // HIG standard side margin on iPhone
    static let betweenCards: CGFloat = 12    // gap between cards on Today
    static let insideCard: CGFloat = 14      // padding inside a card
    static let minTarget: CGFloat = 44       // HIG minimum tap size
}

// MARK: - Corner radius

// corner sizes
enum Radius {
    static let card: CGFloat = 20
    static let tile: CGFloat = 12
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
