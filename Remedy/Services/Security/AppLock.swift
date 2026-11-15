//
//  AppLock.swift
//  Remedy
//
//  optional Face ID or passcode lock, off by default
//

import Foundation
import LocalAuthentication
import Observation

// optional face id or passcode lock, off by default
@Observable
@MainActor
final class AppLock {

    static let settingKey = "appLockOn"

    private(set) var isLocked: Bool
    private(set) var failed = false
    // cover the screen while inactive (app switcher) without locking for good
    private(set) var isCovered = false
    private var isAsking = false
    private let defaults: UserDefaults
    // swappable so tests need no device
    private let authenticate: () async -> Bool
    // false when the phone has no passcode at all, so no lock can work
    private let canAuthenticate: () -> Bool

    init(defaults: UserDefaults = .standard,
         authenticate: @escaping () async -> Bool = AppLock.deviceAuthenticate,
         canAuthenticate: @escaping () -> Bool = { true }) {
        self.defaults = defaults
        self.authenticate = authenticate
        self.canAuthenticate = canAuthenticate
        // a cold start with the lock on begins locked
        isLocked = defaults.bool(forKey: AppLock.settingKey)
    }

    // the real lock for the running app
    static func live() -> AppLock { AppLock(canAuthenticate: AppLock.deviceCanAuthenticate) }

    var isEnabled: Bool { defaults.bool(forKey: AppLock.settingKey) }

    // the app went to the background
    func didEnterBackground() {
        if isEnabled { isLocked = true }
    }

    // the scene went inactive or came back
    func sceneBecameInactive() { if isEnabled { isCovered = true } }
    func sceneBecameActive() { isCovered = false }

    // turning the lock off opens it
    func settingChanged() {
        if !isEnabled { isLocked = false; failed = false; isCovered = false }
    }

    // asks for Face ID or the passcode
    func unlock() async {
        guard isLocked, !isAsking else { return }
        isAsking = true
        let ok = await authenticate()
        isAsking = false
        if ok {
            isLocked = false; failed = false
        } else if !canAuthenticate() {
            // the passcode was removed after the lock was turned on so never trap the patient out
            defaults.set(false, forKey: AppLock.settingKey)
            isLocked = false; failed = false; isCovered = false
        } else {
            failed = true
        }
    }

    // face id with the passcode as backup
    nonisolated static func deviceAuthenticate() async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                    localizedReason: "Unlock Remedy")
        } catch {
            return false
        }
    }

    // can this phone check a passcode or Face ID right now
    nonisolated static func deviceCanAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    // turning the lock on first needs a good Face ID or passcode so nobody locks themselves out
    nonisolated static func verifyBeforeEnabling() async -> LockCheck {
        let context = LAContext()
        return await LockCheck.run(
            canEvaluate: {
                var error: NSError?
                return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) ? nil : error
            },
            evaluate: {
                try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                 localizedReason: "Check it works before Remedy locks")
            })
    }
}

// the answer when checking the lock before turning it on
enum LockCheck: Equatable {
    case verified
    case cancelled
    case problem(String)

    static let failedText = "That did not work, so the lock stays off. Please try again."
    static let unavailableText = "Face ID and the passcode are not available right now, so the lock stays off."

    // pure so tests need no device
    static func run(canEvaluate: () -> Error?, evaluate: () async throws -> Bool) async -> LockCheck {
        if let error = canEvaluate() { return .problem(message(for: error)) }
        do {
            return try await evaluate() ? .verified : .problem(failedText)
        } catch {
            switch (error as? LAError)?.code {
            case .userCancel, .systemCancel, .appCancel: return .cancelled
            default: return .problem(message(for: error))
            }
        }
    }

    // plain words for why the lock can not be turned on
    static func message(for error: Error) -> String {
        switch (error as? LAError)?.code {
        case .passcodeNotSet:
            return "This iPhone has no passcode. Set one in the iPhone\u{2019}s Settings app, then turn the lock on."
        case .biometryNotEnrolled:
            return "Face ID is not set up on this iPhone. Set it up or add a passcode in the Settings app, then try again."
        case .biometryLockout:
            return "Face ID is locked after too many tries. Use your passcode to unlock the phone, then try again."
        case .biometryNotAvailable:
            return unavailableText
        case .authenticationFailed:
            return failedText
        default:
            return unavailableText
        }
    }
}
