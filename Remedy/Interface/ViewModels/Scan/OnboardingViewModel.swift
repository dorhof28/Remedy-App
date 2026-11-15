//
//  OnboardingViewModel.swift
//  Remedy
//
//  the short setup before the first plan is saved: lock, calendar and reminders
//  one step per screen in both looks, each answer remembered and changeable in Settings
//

import EventKit
import Foundation
import LocalAuthentication
import Observation
import UserNotifications

// one setup step
enum SetupStep: String, CaseIterable, Identifiable {
    case name, lock, calendar, reminders, checkIn
    var id: String { rawValue }
}

// what the phone says about a permission
enum PermissionState: Equatable {
    case notAsked, allowed, denied
}

// what the phone can do, read once so tests need no device
struct SetupFacts: Equatable {
    var canLock = true
    var lockName = "Face ID"        // face id, touch id, optic id or passcode
    var calendar = PermissionState.notAsked
    var notifications = PermissionState.notAsked
}

// the setup steps before the first plan: name, lock, calendar, reminders, check-in time
@Observable
@MainActor
final class OnboardingViewModel {

    // the phone side, swapped in tests
    struct Device {
        var facts: () async -> SetupFacts
        var checkLock: () async -> LockCheck
        var askCalendar: () async -> Bool
        var askNotifications: () async -> Bool

        static let live = Device(
            facts: { await OnboardingViewModel.liveFacts() },
            checkLock: { await AppLock.verifyBeforeEnabling() },
            askCalendar: { (try? await CalendarService.store.requestFullAccessToEvents()) ?? false },
            askNotifications: {
                (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            })
    }

    private let defaults: UserDefaults
    private let device: Device
    private let skips: Bool
    private let asksProfile: Bool                // the name and check-in time steps, first run only
    private let saveName: (String) -> Void
    var nameSaved: () -> Void = {}               // the flow refreshes the names it hides

    // typed name and picked time, kept until the plan exists
    var nameText = ""
    var checkInMinute = CheckInTime.defaultMinute
    var surgeryIsLater = false
    static let checkInKey = "setup.checkInMinute"

    private(set) var steps: [SetupStep] = []
    private(set) var index = 0
    private(set) var facts = SetupFacts()
    private(set) var isWorking = false
    private(set) var isLoaded = false
    var message: String?            // a lock that could not turn on says why
    private(set) var doneCount = 0  // bumped after each answer for the haptic

    // nil device and skips use the real phone and the launch option
    init(defaults: UserDefaults = .standard, device: Device? = nil,
         skips: Bool? = nil, asksProfile: Bool = false,
         saveName: ((String) -> Void)? = nil) {
        self.asksProfile = asksProfile
        self.saveName = saveName ?? { PatientNames.addTypedName($0) }
        self.defaults = defaults
        self.device = device ?? .live
        self.skips = skips ?? LaunchOptions.skipsPermissionPrompts
    }

    // MARK: - Which steps show

    static func askedKey(_ step: SetupStep) -> String { "setupAsked.\(step.rawValue)" }

    func wasAsked(_ step: SetupStep) -> Bool { defaults.bool(forKey: Self.askedKey(step)) }

    // pure so tests can check every case
    // a step shows once, never after an answer, and never when the phone already decided it
    static func stepsToShow(asked: Set<SetupStep>, lockOn: Bool, calendarOn: Bool,
                            facts: SetupFacts, skips: Bool, asksProfile: Bool = false) -> [SetupStep] {
        guard !skips else { return [] }
        return SetupStep.allCases.filter { step in
            guard !asked.contains(step) else { return false }
            switch step {
            case .name, .checkIn: return asksProfile
            case .lock: return facts.canLock && !lockOn
            case .calendar: return facts.calendar == .notAsked && !calendarOn
            case .reminders: return facts.notifications == .notAsked
            }
        }
    }

    // reads the phone then picks the steps, safe to call more than once
    func load() async {
        facts = await device.facts()
        let asked = Set(SetupStep.allCases.filter(wasAsked))
        steps = Self.stepsToShow(asked: asked, lockOn: defaults.bool(forKey: AppLock.settingKey),
                                 calendarOn: defaults.bool(forKey: CalendarService.planOnKey),
                                 facts: facts, skips: skips, asksProfile: asksProfile)
        index = 0
        isLoaded = true
    }

    var hasSteps: Bool { !steps.isEmpty }
    var current: SetupStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isFinished: Bool { isLoaded && current == nil }

    // "Step 1 of 3"
    var progressText: String { steps.count > 1 ? "Step \(index + 1) of \(steps.count)" : "" }

    // MARK: - Words

    func symbol(_ step: SetupStep) -> String {
        switch step {
        case .name: return "person.crop.circle.fill"
        case .checkIn: return "heart.text.clipboard"
        case .lock:
            switch facts.lockName {
            case "Touch ID": return "touchid"
            case "Optic ID": return "opticid"
            case "Face ID": return "faceid"
            default: return "lock.fill"
            }
        case .calendar: return "calendar.badge.plus"
        case .reminders: return "bell.badge.fill"
        }
    }

    func title(_ step: SetupStep) -> String {
        switch step {
        case .lock: return "Keep your plan private"
        case .calendar: return "Add visits to your Calendar"
        case .reminders: return "Get dose reminders"
        case .name: return "What\u{2019}s your name?"
        case .checkIn: return "When should we remind you to check in?"
        }
    }

    // one sentence of why
    func reason(_ step: SetupStep) -> String {
        switch step {
        case .lock: return "Remedy asks for \(facts.lockName) when it opens, so only you can see your medicines."
        case .calendar: return "Your surgery, visits and stop days go in a Remedy calendar that stays up to date."
        case .reminders: return "Your iPhone tells you when each medicine is due, with an \u{201C}I took it\u{201D} button."
        case .name: return "A first name is enough. It stays on this phone, and Remedy hides it from papers before they are read."
        case .checkIn:
            return surgeryIsLater ? "Check-ins start the day after your surgery. Pick the time you would like a gentle reminder."
                                  : "A short check-in once a day. Pick the time you would like a gentle reminder."
        }
    }

    func allowButton(_ step: SetupStep) -> String {
        switch step {
        case .lock: return facts.lockName == "Passcode" ? "Use my passcode" : "Turn on \(facts.lockName)"
        case .calendar: return "Add to Calendar"
        case .reminders: return "Turn on reminders"
        case .name: return "Continue"
        case .checkIn: return "Save \(CheckInTime.text(minute: checkInMinute))"
        }
    }

    let notNowButton = "Not now"
    func notNowButton(_ step: SetupStep) -> String { step == .name ? "Skip" : notNowButton }
    func settingsNote(_ step: SetupStep) -> String {
        step == .name ? "Optional." : (step == .checkIn ? "You can change this any time in Settings." : settingsNote)
    }
    let settingsNote = "You can change this any time in Settings."

    // MARK: - Answers

    // the real system prompt for this step
    func allow() async {
        guard let step = current, !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }
        switch step {
        case .name:
            saveTypedName()
        case .checkIn:
            defaults.set(CheckInTime.clamped(checkInMinute), forKey: Self.checkInKey)
        case .lock:
            switch await device.checkLock() {
            case .verified:
                defaults.set(true, forKey: AppLock.settingKey)
            case .cancelled:
                return      // stays on this step so the patient can try again or pick Not now
            case .problem(let text):
                message = text
                return
            }
        case .calendar:
            defaults.set(await device.askCalendar(), forKey: CalendarService.planOnKey)
        case .reminders:
            defaults.set(await device.askNotifications(), forKey: NotificationService.enabledKey)
        }
        finish(step)
    }

    // "Not now" keeps the feature off and never asks again
    func notNow() {
        guard let step = current, !isWorking else { return }
        message = nil
        switch step {
        case .name, .checkIn: break         // nothing is stored, Settings can still set the time
        case .lock: defaults.set(false, forKey: AppLock.settingKey)
        case .calendar: defaults.set(false, forKey: CalendarService.planOnKey)
        // off so the reminder refresh never pops the system question by itself
        case .reminders: defaults.set(false, forKey: NotificationService.enabledKey)
        }
        finish(step)
    }

    // a blank name is the same as Skip
    private func saveTypedName() {
        let clean = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        saveName(clean)
        nameSaved()
    }

    // marks the step asked so it never shows again
    private func finish(_ step: SetupStep) {
        defaults.set(true, forKey: Self.askedKey(step))
        doneCount += 1
        Motion.run { index += 1 }
    }

    // MARK: - The phone

    // what this phone can do right now, read without asking for anything
    static func liveFacts() async -> SetupFacts {
        var facts = SetupFacts()
        let context = LAContext()
        facts.canLock = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: facts.lockName = "Face ID"
        case .touchID: facts.lockName = "Touch ID"
        case .opticID: facts.lockName = "Optic ID"
        default: facts.lockName = "Passcode"
        }
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: facts.calendar = .notAsked
        case .fullAccess: facts.calendar = .allowed
        default: facts.calendar = .denied
        }
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: facts.notifications = .notAsked
        case .denied: facts.notifications = .denied
        default: facts.notifications = .allowed
        }
        return facts
    }
}
