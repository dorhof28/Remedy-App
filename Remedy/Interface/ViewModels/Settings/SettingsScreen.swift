//
//  SettingsScreen.swift
//  Remedy
//
//  words for the redesigned settings (screens 59 to 75)
//

import Foundation

// the classic settings rows and their subtitles
struct SettingsScreen {
    let plan: CarePlan?
    let now: Date
    var defaults: UserDefaults = .standard

    // MARK: - 59 Settings

    let title = "Settings"
    let doneTitle = "Done"
    let remindersTitle = "Reminders"
    let lookTitle = "Look"
    let lookFooter = "Automatic uses Simple when your iPhone text is set to one of the extra-large accessibility sizes, and Classic otherwise. Simple has big buttons and one thing per screen."
    let themeTitle = "Colors"
    let privacyTitle = "Privacy"
    let surgeryTitle = "Your surgery"
    let papersTitle = "Papers"
    let backupTitle = "Backup and restore"
    let demoTitle = "Demo mode"
    let aboutTitle = "About and credits"
    let footer = "Remedy helps you read your papers. It doesn\u{2019}t replace your doctor."

    static let lastBackupKey = "lastBackupAt"

    var remindersValue: String {
        (defaults.object(forKey: NotificationService.enabledKey) as? Bool ?? true) ? "On" : "Off"
    }
    var demoValue: String { defaults.bool(forKey: LaunchOptions.demoModeKey) ? "On" : "Off" }

    // "Knee replacement · Mon, Nov 9"
    var surgerySubtitle: String {
        guard let plan else { return "" }
        let date = plan.surgeryDate.map { DayMath.shortDate($0) } ?? ""
        return [PlainText.upperFirst(plan.procedure), date].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }

    var papersSubtitle: String {
        let count = plan?.papers.count ?? 0
        return count == 0 ? "" : PlainText.count(count, "paper")
    }

    // "Last backup: today"
    var backupSubtitle: String {
        guard let last = lastBackup else { return "No backup yet" }
        return "Last backup: \(Self.dayWords(last, now: now))"
    }

    var lastBackup: Date? {
        let seconds = defaults.double(forKey: Self.lastBackupKey)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    static func dayWords(_ date: Date, now: Date) -> String {
        let days = DayMath.dayOffset(of: date, from: now)
        if days == 0 { return "today" }
        if days == -1 { return "yesterday" }
        return DayMath.shortDate(date)
    }

    // MARK: - 60 Reminders

    let doseToggle = "Dose and visit reminders"
    let doseSubtitle = "With I Took It and Snooze buttons"
    let checkInTitle = "Daily check-in"
    let stopDaysToggle = "Ask me on stop days"
    let stopDaysSubtitle = "One question: did you take any?"
    let stopDaysFooter = "Stop-day questions start 7 days before surgery."
    let otherAppsTitle = "Other apps"
    let calendarToggle = "Add my plan to Calendar"
    let calendarSubtitle = "Surgery, stop days, visits"
    let remindersAppTitle = "Add To-Dos to Reminders"
    let otherAppsFooter = "Remedy makes its own calendar and never reads your other calendars. Add To-Dos to Reminders gets its own one-button screen, then Apple\u{2019}s prompt with Don\u{2019}t Allow."
    let calendarOffText = "Calendar is off for Remedy. Turn it on in Settings."
    let openSettings = "Open Settings"
    let notSet = "Not set"

    // MARK: - 63 Privacy

    let permissionsTitle = "Permissions"
    let permissionsFooter = "Tap one to change it in iOS Settings."
    let cloudToggle = "Use cloud AI to read papers"
    let lockToggle = "Lock with Face ID"
    let howReadTitle = "How Papers Are Read"
    let stepsToggle = "Show my steps on Today"
    let privacyFooter = "Remedy always shows what the AI will see and asks before sending each paper."
    let clearChat = "Clear Chat"
    let deleteAll = "Delete All Data"
    let deleteAllAction = "Delete All Remedy Data"
    let deleteAllMessage = "This removes your plan, papers, dose log, check-ins, photos, chat and the names to hide from this iPhone. AI keys and settings stay. It can\u{2019}t be undone."
    let clearChatMessage = "This deletes the questions and answers on this iPhone. Your plan stays."

    // "Plan made by: Apple cloud"
    func plannerSubtitle(_ name: String) -> String { "Plan made by: \(name)" }

    // MARK: - 64 How papers are read

    let stepsFooter = "Only step 3 can leave the phone, and only after \u{201C}What the AI will see\u{201D}."
    let namesTitle = "Names to Hide"
    let modelsTitle = "Downloaded Models"

    // "Ruth Alvarez and 1 more"
    static func namesSubtitle(_ names: [String]) -> String {
        guard let first = names.first else { return "None yet" }
        return names.count == 1 ? first : "\(first) and \(names.count - 1) more"
    }

    // MARK: - 68 Names to hide

    let addName = "Add a Name or Word"
    let namesFooter = "Add other spellings or nicknames. Remedy also hides birth dates, record numbers (MRN, CEID), addresses and phone numbers on its own."
    let yourName = "Your name"
    let otherSpelling = "Another spelling"
    let namePrompt = "Name or word"
    let removeName = "Remove"

    // MARK: - 71 Backup

    let backupPageTitle = "Backup and Restore"
    let makeBackup = "Make a Backup"
    let restoreBackup = "Restore From a Backup"
    let restoreSubtitle = "Replaces the plan on this iPhone"
    let backupFooter = "A backup is one file locked with a password. Keep it in Files or iCloud Drive. Restoring asks first, because it replaces what\u{2019}s here."

    // "Last backup: today, 3:10 AM"
    var makeBackupSubtitle: String {
        guard let last = lastBackup else { return "No backup yet" }
        return "Last backup: \(Self.dayWords(last, now: now)), \(DayMath.timeText(of: last))"
    }

    // MARK: - 75 About

    let aboutPageTitle = "About"
    let appName = "Remedy"
    let versionLabel = "Version"
    let madeByLabel = "Made by"
    let madeBy = "Dorron Hoffman and Nikhil Shah"
    let acknowledgements = "Acknowledgements"
    let aboutFooter = "Remedy helps you read your papers. It doesn\u{2019}t replace your doctor. In an emergency, call 911."

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
