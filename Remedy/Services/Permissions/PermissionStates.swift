//
//  PermissionStates.swift
//  Remedy
//
//  reads each permission's state for the privacy page, never asks for one
//

import AVFoundation
import EventKit
import Foundation
import UserNotifications

// a permission's state as the privacy page words it
enum AccessState: String {
    case allowed = "Allowed"
    case denied = "Off"
    case notAsked = "Not asked"
    case limited = "Add only"
}

// reads each permission without asking for it
enum PermissionStates {

    static var camera: AccessState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .allowed
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    static var calendar: AccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .allowed
        case .writeOnly: return .limited
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    static func notifications() async -> AccessState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }

    // health can't be read back for privacy, so only whether Remedy asked
    static var health: AccessState {
        UserDefaults.standard.bool(forKey: HealthService.stepsOnKey) ? .allowed : .notAsked
    }
}
