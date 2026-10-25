//
//  AppLook.swift
//  Remedy
//
//  classic or simple look picked in settings
//

import Foundation

enum AppLook: String, CaseIterable, Identifiable {
    case classic
    case simple

    // the key it's saved under
    static let storageKey = "appLook"

    var id: String { rawValue }

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
