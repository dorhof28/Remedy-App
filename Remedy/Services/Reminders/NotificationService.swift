//
//  NotificationService.swift
//  Remedy
//
//  sends reminders and handles their buttons
//

import Foundation
import SwiftData
import UserNotifications

// schedules reminders and handles their buttons
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    // off switch in Settings
    static let enabledKey = "remindersOn"

    private let center = UNUserNotificationCenter.current()
    private var container: ModelContainer?

    // names for the buttons on a dose notification
    private static let doseCategory = "DOSE"
    private static let tookItAction = "TOOK_IT"
    private static let snoozeAction = "SNOOZE"
    private static let medicinesKey = "medicines"
    private static let timeKey = "time"
    static let snoozeMinutes = 10

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    // MARK: - Start (once, when the app opens)

    // call once when the app opens
    func start(container: ModelContainer) {
        self.container = container
        center.delegate = self
        let tookIt = UNNotificationAction(identifier: Self.tookItAction, title: "I Took It", options: [],
                                          icon: UNNotificationActionIcon(systemImageName: "checkmark"))
        let snooze = UNNotificationAction(identifier: Self.snoozeAction, title: "Snooze \(Self.snoozeMinutes) Minutes", options: [],
                                          icon: UNNotificationActionIcon(systemImageName: "clock"))
        let dose = UNNotificationCategory(identifier: Self.doseCategory, actions: [tookIt, snooze], intentIdentifiers: [])
        center.setNotificationCategories([dose])
    }

    // MARK: - Schedule

    // asks once then schedules the next few days
    func refresh(plan: CarePlan?, now: Date) async {
        center.removeAllPendingNotificationRequests()
        guard isEnabled, let plan else { return }

        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            let allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard allowed else { return }
        } else if settings.authorizationStatus == .denied {
            return
        }

        // days already checked in need no reminder
        let checked = Set(((try? container?.mainContext.fetch(FetchDescriptor<CheckIn>())) ?? []).map(\.day))
        for item in ReminderPlan.itemsWithCheck(for: plan, now: now, checkedInDays: checked) {
            try? await center.add(request(for: item))
        }

        // ask-by calls, replaced with the rest when resolved findings drop out
        if let surgery = plan.surgeryDate {
            let contact = plan.contacts.first { $0.role == .careTeam && !$0.phone.isEmpty }?.name
            let findings = PaperCheckReport.of(plan).result.findings
            for reminder in AskByReminder.reminders(for: findings, surgeryDate: surgery, contactName: contact, now: now) {
                try? await center.add(askByRequest(reminder))
            }
        }
    }

    // the reminder to call the office about a red card
    private func askByRequest(_ reminder: AskByReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.interruptionLevel = .active
        // a passed ask-by day repeats at 9 AM every day, the next refresh drops it once resolved or the plan changed
        let units: Set<Calendar.Component> = reminder.repeatsDaily ? [.hour, .minute] : [.year, .month, .day, .hour, .minute]
        let parts = DayMath.calendar.dateComponents(units, from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: reminder.repeatsDaily)
        return UNNotificationRequest(identifier: reminder.findingKey, content: content, trigger: trigger)
    }

    // turns everything off
    func stopAll() {
        center.removeAllPendingNotificationRequests()
    }

    // "Allowed" "Off in iPhone Settings" for the Settings screen
    func statusText() async -> String {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Turned off in the iPhone\u{2019}s Settings app"
        default: return "Not set up yet"
        }
    }

    // one reminder as a notification request
    private func request(for item: ReminderItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.interruptionLevel = item.kind == .dose ? .timeSensitive : .active
        if item.kind == .dose {
            content.categoryIdentifier = Self.doseCategory
            content.userInfo = [Self.medicinesKey: Self.encode(item.medicineIDs),
                                Self.timeKey: item.date.timeIntervalSince1970]
        }
        let parts = DayMath.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        return UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)
    }

    // MARK: - Remind me again (Not Now on Today)

    // one reminder in a few minutes for a dose put off on Today, only if reminders are allowed
    func remindAgain(title: String, body: String, inMinutes minutes: Int) async {
        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "again-\(UUID())", content: content, trigger: trigger))
    }

    // MARK: - While the app is open: still show it as a banner

    // shows reminders even while the app is open
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // MARK: - Buttons on the notification

    // the took it button logs the dose without opening the app
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        switch response.actionIdentifier {
        case Self.tookItAction:
            logTaken(userInfo: content.userInfo)
        case Self.snoozeAction:
            let again = content.mutableCopy() as? UNMutableNotificationContent ?? UNMutableNotificationContent()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(Self.snoozeMinutes * 60), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "snooze-\(UUID())", content: again, trigger: trigger))
        default:
            break       // tapping the notification just opens the app
        }
    }

    // logs every medicine on the notification as taken
    private func logTaken(userInfo: [AnyHashable: Any]) {
        guard let container,
              let encoded = userInfo[Self.medicinesKey] as? String,
              let seconds = userInfo[Self.timeKey] as? TimeInterval else { return }
        let context = container.mainContext
        let time = Date(timeIntervalSince1970: seconds)
        for id in Self.decode(encoded) {
            if let medicine = context.model(for: id) as? MedicineInstruction {
                DoseActions.log(medicine, scheduledFor: time, as: .taken, now: AppClock.now(), in: context)
            }
        }
    }

    // MARK: - Saving medicine IDs inside a notification

    private static func encode(_ ids: [PersistentIdentifier]) -> String {
        guard let data = try? JSONEncoder().encode(ids) else { return "" }
        return data.base64EncodedString()
    }

    // medicine ids packed into the notification
    private static func decode(_ text: String) -> [PersistentIdentifier] {
        guard let data = Data(base64Encoded: text),
              let ids = try? JSONDecoder().decode([PersistentIdentifier].self, from: data) else { return [] }
        return ids
    }
}
