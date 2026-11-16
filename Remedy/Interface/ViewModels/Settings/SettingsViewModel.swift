//
//  SettingsViewModel.swift
//  Remedy
//
//  settings for both looks
//

import Foundation
import SwiftData

// settings shared by both looks: readers, keys, backup, reminders and pages
struct SettingsViewModel {

    let plan: CarePlan?
    let now: Date
    var defaults: UserDefaults = .standard

    // MARK: - Words

    let title = "Settings"
    let doneTitle = "Done"
    let surgeryTitle = "Your surgery"
    let surgeryDateLabel = "Surgery date"
    let dateFootnote = "Every date in your plan moves with your surgery date."
    let privacyTitle = "Privacy"
    let privacyText = "Your papers and plan stay on this phone. Names and record numbers are removed on the phone before anything is sent to the AI."
    let lockToggle = "Lock with Face ID or passcode"
    let lockFooter = "Remedy locks when you leave it. Open it again with Face ID or your iPhone passcode. We check it works before the lock turns on."
    let lockProblemTitle = "Couldn\u{2019}t turn on the lock"
        let privacySecurityTitle = "Privacy and lock"
    let appearanceTitle = "Look and colors"
    let dataTitle = "Your data"
    let clearChatTitle = "Clear chat"
    let clearChatMessage = "This deletes your questions and answers. Your plan stays."
    let deletePlanTitle = "Delete my plan"
    let deletePlanMessage = "This deletes your plan, medicines, doses, check-ins, photos and chat from this phone. You can scan your papers again."
    let aboutTitle = "About"
    let versionLabel = "Version"
    // the brand line under settings and on the about page
    static let motto = "Your health, made simple"
    var motto: String { Self.motto }
    let disclaimer = "Remedy helps you follow the papers your care team gave you. It is not medical advice. Always follow your care team, and call 911 in an emergency."
    let creditsLabel = "Made by"
    let creditsText = "Dorron Hoffman and Nikhil Shah"
    let demoTitle = "Demo"

    var hasPlan: Bool { plan != nil }

    // asks Face ID or the passcode before the lock is allowed to turn on
    func checkLockWorks() async -> LockCheck {
        await AppLock.verifyBeforeEnabling()
    }

    // MARK: - Reminders

    let remindersTitle = "Reminders"
    var hasOpenTasks: Bool { plan?.tasks.contains { !$0.isDone } ?? false }

    // puts open to-dos in Apple Reminders
    func addTasksToReminders() async -> String {
        guard let plan, let surgeryDate = plan.surgeryDate else { return "Add your surgery date first." }
        do {
            let added = try await CalendarService.addToReminders(plan.tasks, surgeryDate: surgeryDate)
            return added == 0 ? "Remedy isn\u{2019}t allowed to use Reminders. You can change that in the iPhone\u{2019}s Settings app."
                              : "Added \(PlainText.count(added, "to-do")) to the \u{201C}Remedy\u{201D} list in Reminders."
        } catch {
            return "Couldn\u{2019}t add them to Reminders. Please try again."
        }
    }

    // MARK: - Stop day question

    let lastDoseToggle = "Ask me on stop days"
    let lastDoseFooter = "On a stop day, Remedy asks if you took any of that medicine. It is only a question."

    // MARK: - Calendar

    let calendarToggle = "Add my plan to Calendar"
    let calendarDeniedText = "Remedy isn\u{2019}t allowed to use Calendar. You can change that in the iPhone\u{2019}s Settings app."

    // turns the Remedy calendar on or off, returns a message if it could not
    func setCalendar(_ isOn: Bool) async -> String? {
        if isOn {
            return await CalendarService.syncPlan(plan, defaults: defaults) ? nil : calendarDeniedText
        }
        await CalendarService.removePlan(defaults: defaults)
        return nil
    }

    // turns reminders on or off
    func setReminders(_ isOn: Bool) {
        if isOn {
            Task { await NotificationService.shared.refresh(plan: plan, now: now) }
        } else {
            NotificationService.shared.stopAll()
        }
    }

    // MARK: - Who reads your papers

    let readerTitle = "Who reads your papers"
    let readerIntro = "Pick the AI that builds your plan from your papers. Remedy never switches to another one by itself."
    let changeTitle = "Change"
    let cloudWarning = "The blacked-out page leaves your phone."
    let simpleNeedsKeyText = "Add its key under About, All settings to use it."
    let homeNetworkNote = "Stays on your home network"
    let notAvailableText = "Not available yet"
    let textOnlyToggle = "Send text only"
    let textOnlyFooter = "Leaves out the blacked-out photo. Only the cleaned text is sent. Google\u{2019}s free tier may use what it gets to improve its AI, so only use a free key with sample papers."
    let hideToggle = "Hide names and addresses before sending"
    let hideFooter = "Names and addresses are hidden on this phone before any AI sees your papers."
    let hideOffTitle = "Turn off hiding?"
    let hideOffButton = "Turn off anyway"
    let hideKeepButton = "Keep hiding"
    let keyPrompt = "API key"
    let urlPrompt = "Server address"
    let macPrompt = "Your Mac\u{2019}s name, like Dorrons-MacBook"
    let modelPrompt = "Model name"
    let saveKeyTitle = "Save key"
    let removeKeyTitle = "Remove key"
    let keySavedText = "Key saved on this phone"
    let themeTitle = "Theme"

    // one heading in the list with the choices that exist
    struct ReaderGroup: Identifiable {
        let id: ModelChoice.Group
        let title: String
        let choices: [ModelChoice]
        var showsTextOnly: Bool { id == .cloud }
    }

    var readerGroups: [ReaderGroup] {
        let titles: [(ModelChoice.Group, String)] = [
            (.onPhone, "On this iPhone"), (.offlineDownload, "Offline downloads"),
            (.applePrivateCloud, "Apple Private Cloud"), (.yourMac, "Your own Mac"), (.cloud, "Cloud"),
        ]
        return titles.compactMap { group, title in
            let choices = ModelChoice.all.filter { $0.group == group }
            return choices.isEmpty ? nil : ReaderGroup(id: group, title: title, choices: choices)
        }
    }

    // the planner now, "On this iPhone" until the patient picks another
    var planner: ModelChoice { ModelSettings.load(from: defaults).plannerChoice }

    // the line under a choice about where the papers go
    func privacyNote(for choice: ModelChoice) -> String? {
        if choice.group == .yourMac { return homeNetworkNote }
        return choice.group == .cloud ? cloudWarning : nil
    }

    // Apple's cloud stays off until Apple approves it
    func isSelectable(_ choice: ModelChoice) -> Bool {
        choice.id != .applePrivateCloud || AppleAI.usesCloud
    }

    // picks the plan reader when it can run now
    func choosePlanner(_ choice: ModelChoice) {
        guard isSelectable(choice) else { return }
        var settings = ModelSettings.load(from: defaults)
        settings.plannerChoice = choice
        settings.save(to: defaults)
    }

    // turning hiding off while the planner sends data off the phone needs a yes first
    var confirmsTurningOffHiding: Bool {
        ModelSettings(plannerChoice: planner, redactBeforePlanning: false).needsRedactionWarning
    }
    var hideOffMessage: String { "Your name and address may be sent to \(planner.displayName)." }

    // MARK: - Keys (Keychain only)

    // the keychain name of a reader's key, nil when it needs none
    private func keyName(for choice: ModelChoice) -> String? {
        switch choice.id {
        case .claude: return ClaudeAdapter.keyName
        case .gemini: return GeminiPlanReader.keyName
        case .openAI, .openRouter, .groq, .mistral, .openAICompatible: return OpenAICompatibleAdapter.keyName(for: choice)
        case .onPhone, .applePrivateCloud, .yourMac: return nil
        }
    }

    func hasKey(_ choice: ModelChoice) -> Bool {
        keyName(for: choice).flatMap { KeychainStore.read($0) }.map { !$0.isEmpty } ?? false
    }

    // real keys are long this stops a half-pasted one a private server may use a short one
    func canSave(_ key: String, for choice: ModelChoice) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).count >= (choice.usesCompatibleAdapter ? 1 : 20)
    }

    func saveKey(_ key: String, for choice: ModelChoice) {
        guard let name = keyName(for: choice) else { return }
        KeychainStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), for: name)
    }

    func removeKey(for choice: ModelChoice) {
        guard let name = keyName(for: choice) else { return }
        KeychainStore.delete(name)
    }

    // MARK: - Apple Health

    var showsHealth: Bool { HealthService.isAvailable }

    // turning the switch on asks iOS for permission to read steps
    func setHealthSteps(_ isOn: Bool) {
        guard isOn else { return }
        Task { await HealthService.askForSteps() }
    }

    // MARK: - Look

    let lookTitle = "Look"
    let lookFooter = "Simple has big buttons and big text. You can switch any time; nothing is lost."
    let looks = AppLook.allCases

    let papersTitle = "Your papers"
    var hasSurgeryDate: Bool { plan?.surgeryDate != nil }

    // MARK: - Your surgery

    var procedure: String {
        guard let plan, !plan.procedure.isEmpty else { return "Not set" }
        return plan.procedure
    }

    // what the date pickers start on
    var surgeryDate: Date { plan?.surgeryDate ?? now }
    var dischargeDate: Date { plan?.dischargeDate ?? plan?.surgeryDate ?? now }

    // MARK: - About

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    // moves the whole plan
    func setSurgeryDate(_ date: Date, in context: ModelContext) {
        guard let plan else { return }
        PlanActions.setSurgeryDate(date, on: plan, in: context)
        // events follow the new date
        if defaults.bool(forKey: CalendarService.planOnKey) {
            // read the plan now, the task may run after it is gone
            let wanted = CalendarService.snapshot(of: plan)
            Task { await CalendarService.sync(wanted, defaults: defaults) }
        }
    }

    // home from hospital date
    func setDischargeDate(_ date: Date, in context: ModelContext) {
        guard let plan else { return }
        PlanActions.setDischargeDate(date, on: plan, in: context)
    }

    // deletes the chat
    func clearChat(in context: ModelContext) {
        ChatActions.deleteAll(in: context)
    }

    // deletes everything, not only the plan, so a new plan never picks up old check-ins or photos
    func deletePlan(in context: ModelContext) {
        PlanActions.deleteEverything(in: context)
    }
}

// MARK: - Backup file (no iCloud yet, a locked file the patient keeps in Files)

extension SettingsViewModel {

    var backupTitle: String { "Backup" }
    var makeBackupTitle: String { "Make a backup" }
    var restoreBackupTitle: String { "Restore from a backup" }
    var chooseBackupTitle: String { "Choose the backup file" }
    var backupFooter: String { "Saves your plan, papers, doses, check-ins and photos in one file locked with a password. Keep it in Files, then open it on a new phone." }
    var backupPasswordIntro: String { "Pick a password for this backup. You need it to open the backup. Remedy can\u{2019}t get it back if you forget it." }
    var passwordPrompt: String { "Password" }
    var passwordAgainPrompt: String { "Type the password again" }
    var lockBackupTitle: String { "Make backup" }
    var backupSavedText: String { "Your backup is saved. Keep the password somewhere safe." }
    var openBackupIntro: String { "Type the password for this backup." }
    var openBackupTitle: String { "Open backup" }
    var inBackupTitle: String { "In this backup" }
    var replaceTitle: String { "Replace my plan" }
    var restoredText: String { "Your plan is back on this phone." }
    var cancelTitle: String { "Cancel" }
    var replaceMessage: String {
        hasPlan ? "This replaces the plan on this phone, with its doses, chat, check-ins and photos. This can\u{2019}t be undone."
                : "This puts the plan from the backup on this phone."
    }

    static let minimumPasswordLength = 8

    // nil when the password can be used
    func backupPasswordProblem(_ password: String, again: String) -> String? {
        if password.count < Self.minimumPasswordLength {
            return "Use at least \(Self.minimumPasswordLength) letters or numbers."
        }
        return password == again ? nil : "The two passwords are different."
    }

    // copies everything then locks it off the main thread
    func makeBackup(password: String, in context: ModelContext) async throws -> Data {
        let snapshot = try BackupSnapshot.make(from: context)
        return try await Task.detached { try BackupFile.seal(snapshot, password: password) }.value
    }

    // decrypting is slow on purpose so it runs off the main thread
    func openBackup(_ data: Data, password: String) async throws -> BackupSnapshot {
        try await Task.detached { try BackupFile.open(data, password: password) }.value
    }

    // replaces everything, the old plan stays if it fails
    func restore(_ snapshot: BackupSnapshot, in context: ModelContext) async throws {
        try snapshot.restore(into: context)
        let plan = PlanActions.currentPlan(in: context)
        let now = AppClock.now()
        // old calendar events belong to the replaced plan so always clear them
        if CalendarService.hasSavedEvents(defaults: defaults) {
            await CalendarService.removePlan(defaults: defaults)
        }
        // the old activity ends then the new plan starts its own
        await LiveActivityManager.sync(plan: nil, now: now)
        if defaults.bool(forKey: CalendarService.planOnKey), let plan {
            await CalendarService.syncPlan(plan, defaults: defaults)
        }
        await NotificationService.shared.refresh(plan: plan, now: now)
        WidgetSnapshotMaker.save(plan: plan, now: now)
        await LiveActivityManager.sync(plan: plan, now: now)
    }

    func backupErrorText(_ error: Error) -> String {
        (error as? BackupError)?.errorDescription ?? "Something went wrong. Nothing on this phone was changed. Please try again."
    }
}

// MARK: - Top level rows (short list, details on their own screens)

extension SettingsViewModel {

    // the pages settings opens
    enum Page: String, CaseIterable, Identifiable {
        case plan, papers, reminders, reading, privacy, appearance, data, demo, about
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .plan: return "cross.case.fill"
            case .papers: return "doc.on.doc.fill"
            case .reminders: return "bell.fill"
            case .reading: return "doc.text.magnifyingglass"
            case .privacy: return "lock.shield.fill"
            case .appearance: return "paintpalette.fill"
            case .data: return "externaldrive.fill"
            case .demo: return "flask.fill"
            case .about: return "info.circle.fill"
            }
        }

        // the icon tile colour, like iOS Settings
        var tone: Tone {
            switch self {
            case .plan, .papers: return .info
            case .reminders: return .stop
            case .reading: return .good
            case .privacy: return .good
            case .appearance: return .caution
            case .data: return .neutral
            case .demo: return .caution
            case .about: return .neutral
            }
        }
    }

    // the groups on the top screen, in order, each with a small heading
    struct PageGroup: Identifiable {
        let title: String
        let pages: [Page]
        var id: String { title }
    }

    var pageGroups: [PageGroup] {
        [PageGroup(title: "Your plan", pages: [.plan, .papers]),
         PageGroup(title: "Reminders and calendar", pages: [.reminders]),
         PageGroup(title: "Reading and privacy", pages: [.reading, .privacy]),
         PageGroup(title: "Look", pages: [.appearance]),
         PageGroup(title: "Data and backup", pages: [.data]),
         PageGroup(title: "More", pages: [.demo, .about])]
    }

    func pageTitle(_ page: Page) -> String {
        switch page {
        case .plan: return surgeryTitle
        case .papers: return PapersSettingsViewModel(plan: plan).title
        case .reminders: return remindersTitle
        case .reading: return readingTitle
        case .privacy: return privacySecurityTitle
        case .appearance: return appearanceTitle
        case .data: return dataTitle
        case .demo: return DemoModeViewModel(defaults: defaults).screenTitle
        case .about: return aboutTitle
        }
    }

    // the current value shown at the right of each row
    func pageValue(_ page: Page) -> String {
        switch page {
        case .plan:
            if let date = plan?.surgeryDate { return date.formatted(.dateTime.month(.abbreviated).day()) }
            return ""
        case .papers: return PapersSettingsViewModel(plan: plan).rowValue
        case .reminders: return isOn(NotificationService.enabledKey, fallback: true) ? "On" : "Off"
        case .reading: return planner.summaryName
        case .privacy: return isOn(AppLock.settingKey, fallback: false) ? "Lock on" : "Lock off"
        case .appearance:
            let look = AppLook(rawValue: defaults.string(forKey: AppLook.storageKey) ?? "") ?? AppLook.defaultLook
            return look.title
        case .data: return ""
        case .demo: return isOn(LaunchOptions.demoModeKey, fallback: false) ? "On" : "Off"
        case .about: return ""
        }
    }

    var readingTitle: String { "Reading and AI" }

    private func isOn(_ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    var leavesFooter: String { "Names and addresses are hidden here before any AI reads your papers." }

    var advancedTitle: String { "All settings" }
}

// MARK: - Choice rows (icon, title, one line)

extension SettingsViewModel {

    var calendarSubtitle: String { "Surgery, stop days, visits and to-dos" }

    func readerSymbol(_ choice: ModelChoice) -> String {
        switch choice.group {
        case .onPhone: return "iphone"
        case .offlineDownload: return "arrow.down.circle.fill"
        case .applePrivateCloud: return "lock.icloud.fill"
        case .yourMac: return "desktopcomputer"
        case .cloud: return "cloud.fill"
        }
    }

    // the one line under a reader: what it costs and where the page goes
    func readerSubtitle(_ choice: ModelChoice) -> String {
        if !isSelectable(choice) { return notAvailableText }
        return [choice.hint, privacyNote(for: choice)].compactMap { $0 }.joined(separator: ". ")
    }

    // plain words for the Simple look
    func simpleReaderSubtitle(_ choice: ModelChoice, isChosen: Bool) -> String {
        if !isSelectable(choice) { return notAvailableText }
        var parts: [String] = []
        if choice.sendsDataOffPhone { parts.append(cloudWarning) }
        if isChosen && choice.needsKey && !hasKey(choice) { parts.append(simpleNeedsKeyText) }
        return parts.joined(separator: " ")
    }
}
