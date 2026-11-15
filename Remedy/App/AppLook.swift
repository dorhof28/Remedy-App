//
//  AppLook.swift
//  Remedy
//
//  classic or simple look picked in settings
//

import Foundation

// the two looks every screen is drawn in
enum AppLook: String, CaseIterable, Identifiable {
    case classic
    case simple

    // the key it's saved under
    static let storageKey = "appLook"

    var id: String { rawValue }

    // the look people start with until they pick one
    static let defaultLook = AppLook.classic

    // makes every @AppStorage of the look start as Simple, a saved choice still wins
    static func registerDefault() {
        UserDefaults.standard.register(defaults: [storageKey: defaultLook.rawValue])
    }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .simple: return "Simple"
        }
    }

    var detail: String {
        switch self {
        case .classic: return "Tabs and cards. Everything on your papers."
        case .simple: return "Big buttons and big text. One thing at a time."
        }
    }
}

// what the patient picked in settings, automatic follows the phone's text size
enum AppLookMode: String, CaseIterable, Identifiable {
    case automatic
    case classic
    case simple

    static let storageKey = "appLookMode"
    // the one-time note after automatic first switches to simple
    static let noteShownKey = "appLookAutoNoteShown"
    static let noteOpenKey = "appLookAutoNoteOpen"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .classic: return "Classic"
        case .simple: return "Simple"
        }
    }

    // the look to draw, accessibility text sizes get simple when automatic
    func look(largeText: Bool) -> AppLook {
        switch self {
        case .automatic: return largeText ? .simple : .classic
        case .classic: return .classic
        case .simple: return .simple
        }
    }

    // a saved look from before automatic existed counts as picked by hand
    static func registerDefault() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: storageKey) == nil, let saved = defaults.string(forKey: AppLook.storageKey),
           defaults.object(forKey: "appLookMigrated") == nil {
            defaults.set(saved == AppLook.simple.rawValue ? simple.rawValue : classic.rawValue, forKey: storageKey)
        }
        defaults.set(true, forKey: "appLookMigrated")
        defaults.register(defaults: [storageKey: automatic.rawValue])
    }
}
