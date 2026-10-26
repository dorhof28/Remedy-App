//
//  SettingsViewModel.swift
//  Remedy
//
//  settings for both looks
//

import Foundation
import SwiftData

struct SettingsViewModel {

    let plan: CarePlan?
    let now: Date

    // MARK: - Words

    let title = "Settings"
    let doneTitle = "Done"
    let surgeryTitle = "Your surgery"
    let procedureLabel = "Surgery"
    let surgeryDateLabel = "Surgery date"
    let dischargeDateLabel = "Home from hospital"
    let dateFootnote = "Every date in your plan moves with your surgery date."
    let privacyTitle = "Privacy"
    let privacyText = "Your papers and plan stay on this phone. Names and record numbers are removed on the phone before anything is sent to the AI."
    let clearChatTitle = "Clear chat"
    let clearChatMessage = "This deletes your questions and answers. Your plan stays."
    let deletePlanTitle = "Delete my plan"
    let deletePlanMessage = "This deletes your plan, medicines and doses from this phone. You can scan your papers again."
    let aboutTitle = "About"
    let versionLabel = "Version"
    let disclaimer = "Remedy helps you follow the papers your care team gave you. It is not medical advice. Always follow your care team, and call 911 in an emergency."
    let creditsLabel = "Made by"
    let creditsText = "Dorron Hoffman and Nikhil Shah"
    let demoTitle = "Demo"

    var hasPlan: Bool { plan != nil }

    // MARK: - Reminders

    let remindersTitle = "Reminders"
    let remindersToggle = "Medicine and visit reminders"
    let remindersFooter = "Notifications at each dose time (with an \u{201C}I took it\u{201D} button), on stop days, and before visits."
    let addToRemindersTitle = "Add my to-dos to the Reminders app"
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

    // turns reminders on or off
    func setReminders(_ isOn: Bool) {
        if isOn {
            Task { await NotificationService.shared.refresh(plan: plan, now: now) }
        } else {
            NotificationService.shared.stopAll()
        }
    }

    // MARK: - Reading your papers (which AI)

    let aiTitle = "Reading your papers"
    let aiUsesLabel = "Uses"
    let geminiKeyPrompt = "Gemini API key"
    let saveKeyTitle = "Save key"
    let removeKeyTitle = "Remove Gemini key"
    let picturesToggle = "Send blacked out photos for better reading"
    let connectionsTitle = "Check MyChart and Health"
    let themeTitle = "Theme"
    let themeFooter = "The new theme shows when you close Settings."
    let aiFooter = "Only the cleaned text and blacked out photos, with your name and numbers removed, are ever sent. Gemini is the backup when Apple\u{2019}s cloud AI isn\u{2019}t available. Google\u{2019}s free tier may use what it gets to improve its AI, so only use a free key with sample papers."

    // "Apple's cloud AI" "Google Gemini" "Apple AI on this phone"
    var aiStatusText: String {
        let reader = PlanReaders.current
        return reader.isAvailable ? reader.name : "Not available on this phone"
    }

    var hasGeminiKey: Bool { GeminiPlanReader().isAvailable }

    // real keys are long this stops a half-pasted one
    func canSave(_ key: String) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    // saves the key in the Keychain
    func saveGeminiKey(_ key: String) {
        KeychainStore.save(key.trimmingCharacters(in: .whitespacesAndNewlines), for: GeminiPlanReader.keyName)
    }

    // deletes the key from the keychain
    func removeGeminiKey() {
        KeychainStore.delete(GeminiPlanReader.keyName)
    }

    // MARK: - Apple Health

    let healthTitle = "Apple Health"
    let healthStepsToggle = "Show my steps on Today"
    let healthFooter = "Remedy only reads from Health, and only what you allow. Your hospital medicines can be imported when you add papers."
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
    let scanMoreTitle = "Scan more papers"
    let scanMoreFooter = "Add your discharge papers after surgery. You check each new item first."
    var hasSurgeryDate: Bool { plan?.surgeryDate != nil }

    // MARK: - Your surgery

    var procedure: String {
        guard let plan, !plan.procedure.isEmpty else { return "Not set" }
        return plan.procedure
    }

    // what the date pickers start on
    var surgeryDate: Date { plan?.surgeryDate ?? now }
    var dischargeDate: Date { plan?.dischargeDate ?? plan?.surgeryDate ?? now }
    var hasDischargeDate: Bool { plan?.dischargeDate != nil }

    // MARK: - About

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Demo (DEMO ONLY: shows how the scheme set things up)

    var showsDemo: Bool { LaunchOptions.usesSamplePlan }
    var demoText: String {
        let day = LaunchOptions.demoDay
        return "Sample patient, saved in memory only. Today is \(DayMath.surgeryWords(forDay: day))."
    }

    // MARK: - Actions

    // moves the whole plan
    func setSurgeryDate(_ date: Date, in context: ModelContext) {
        guard let plan else { return }
        PlanActions.setSurgeryDate(date, on: plan, in: context)
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

    // deletes everything
    func deletePlan(in context: ModelContext) {
        guard let plan else { return }
        ChatActions.deleteAll(in: context)
        PlanActions.deletePlan(plan, in: context)
    }
}
