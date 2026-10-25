//
//  Theme.swift
//  Remedy
//
//  colors spacing corners and animation
//

import SwiftUI
import UIKit

// MARK: - Colours

extension Color {

    // brand mint from the logo - darker than the logo so white text stays readable
    static let remedyTeal = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.16, green: 0.62, blue: 0.51, alpha: 1)   // #2A9D82
        }
        return UIColor(red: 0.08, green: 0.50, blue: 0.41, alpha: 1)       // #158069
    })

    // logo mint and pink for brand touches not text
    static let logoMint = Color(red: 0.48, green: 0.84, blue: 0.75)        // #7BD6C0
    static let logoPink = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.35, green: 0.18, blue: 0.24, alpha: 1)   // #5A2E3D
        }
        return UIColor(red: 0.99, green: 0.76, blue: 0.84, alpha: 1)       // #FCC3D5
    })

    // page behind the cards - a pink wash in light mode
    static let screenBackground = Color(UIColor { (traits: UITraitCollection) -> UIColor in
        if traits.userInterfaceStyle == .dark {
            return UIColor.systemGroupedBackground
        }
        return UIColor(red: 1.0, green: 0.95, blue: 0.97, alpha: 1)        // #FFF2F7
    })
    // white card
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
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
