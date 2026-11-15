//
//  PermissionPrimerText.swift
//  Remedy
//
//  words for the one-button screens shown just before apple's own permission prompt, and after a no
//

import Foundation

// the words shown before ios asks for a permission
struct PermissionPrimerText: Equatable {
    let symbol: String
    let title: String
    let detail: String
    // after don't allow
    let offNavTitle: String
    let offTitle: String
    let offDetail: String
    let otherWayButton: String

    let continueButton = "Continue"
    let openSettingsButton = "Open Settings"
    let backButton = "Back"

    static let camera = PermissionPrimerText(
        symbol: "camera",
        title: "Scan your papers",
        detail: "Remedy uses the camera to take a picture of each page. The pictures stay on this iPhone.",
        offNavTitle: "Scan Papers",
        offTitle: "Camera is off for Remedy",
        offDetail: "To scan papers, turn on the camera in Settings. You can also add photos or a PDF instead.",
        otherWayButton: "Add Photos or a PDF")

    static let notifications = PermissionPrimerText(
        symbol: "bell",
        title: "Get dose reminders",
        detail: "Remedy can remind you when a medicine is due, so you don\u{2019}t have to watch the clock.",
        offNavTitle: "Reminders",
        offTitle: "Notifications are off for Remedy",
        offDetail: "To get dose reminders, turn on notifications in Settings. Today still shows what\u{2019}s due.",
        otherWayButton: "")

    static let calendar = PermissionPrimerText(
        symbol: "calendar",
        title: "Add your plan to Calendar",
        detail: "Remedy puts your surgery, stop days and visits in its own calendar. It never reads your other calendars.",
        offNavTitle: "Calendar",
        offTitle: "Calendar is off for Remedy",
        offDetail: "Calendar is off for Remedy. Turn it on in Settings.",
        otherWayButton: "")
}
