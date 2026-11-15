//
//  SettingsRedesignPages.swift
//  Remedy
//
//  classic settings pages: reminders (60, 61), privacy (63, 70), how papers are read (64), names to hide (68),
//  backup (71) and about (75)
//

import SwiftUI
import SwiftData

// MARK: - 60 Reminders

// which reminders are on and the check-in time
struct RemindersPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @AppStorage(CalendarService.planOnKey) private var calendarOn = false
    @AppStorage(LastDoseQuestion.settingKey) private var asksLastDose = false
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL

    // UI only the calendar pre-screen, the check-in time and messages
    @State private var showsCalendarPrimer = false
    @State private var calendarIsOff = false
    @State private var editsCheckInTime = false
    @State private var message: String?

    var body: some View {
        let screen = SettingsScreen(plan: plans.first, now: AppClock.now())
        let settings = SettingsViewModel(plan: plans.first, now: AppClock.now())
        let checkIn = CheckInViewModel(plan: plans.first, now: AppClock.now())
        List {
            Section {
                Toggle(isOn: $remindersOn) {
                    ListRow(symbol: "bell", title: screen.doseToggle, subtitle: screen.doseSubtitle)
                }
                .tint(Color.accentFill)
                .onChange(of: remindersOn) { _, isOn in settings.setReminders(isOn) }
            }
            Section {
                if plans.first != nil {
                    Button { editsCheckInTime = true } label: {
                        ListRow(symbol: "heart", title: screen.checkInTitle,
                                value: checkIn.checkInMinute.map { CheckInTime.text(minute: $0) } ?? screen.notSet,
                                showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-checkin-time")
                }
                Toggle(isOn: $asksLastDose) {
                    ListRow(symbol: "nosign", tone: .stop, title: screen.stopDaysToggle, subtitle: screen.stopDaysSubtitle)
                }
                .tint(Color.accentFill)
            } footer: {
                Text(screen.stopDaysFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                if settings.hasSurgeryDate {
                    Toggle(isOn: Binding(get: { calendarOn }, set: { isOn in
                        if isOn, PermissionStates.calendar == .notAsked { showsCalendarPrimer = true; return }
                        turnCalendar(isOn, settings)
                    })) {
                        ListRow(symbol: "calendar", title: screen.calendarToggle, subtitle: screen.calendarSubtitle)
                    }
                    .tint(Color.accentFill)
                    if calendarIsOff {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(screen.calendarOffText).font(.subheadline).foregroundStyle(Color.ink2)
                            Button(screen.openSettings) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .foregroundStyle(Color.accentInk)
                            .frame(minHeight: Spacing.minTarget)
                        }
                    }
                }
                if settings.hasOpenTasks {
                    Button {
                        Task { message = await settings.addTasksToReminders() }
                    } label: {
                        ListRow(symbol: "list.bullet", title: screen.remindersAppTitle, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                ListSectionHeader(title: screen.otherAppsTitle)
            } footer: {
                Text(screen.otherAppsFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.remindersTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCalendarPrimer) {
            PermissionPrimerView(text: .calendar) {
                showsCalendarPrimer = false
                turnCalendar(true, settings)
            }
        }
        .sheet(isPresented: $editsCheckInTime) {
            CheckInTimeSheet(current: checkIn.checkInMinute, startsLater: checkIn.day < 0,
                             onSave: { checkIn.setTime($0, in: context); editsCheckInTime = false },
                             onNotNow: { editsCheckInTime = false },
                             onRemove: { checkIn.setTime(nil, in: context); editsCheckInTime = false })
        }
        .alert(screen.remindersTitle, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // apple's own prompt has don't allow, after that the switch stays off and says why
    private func turnCalendar(_ isOn: Bool, _ settings: SettingsViewModel) {
        calendarOn = isOn
        Task {
            let problem = await settings.setCalendar(isOn)
            if isOn, problem != nil { calendarOn = false; calendarIsOff = true } else { calendarIsOff = false }
        }
    }
}

// MARK: - 63 Privacy

// the lock and each permission's state
struct PrivacyPage: View {
    let closeSettings: () -> Void

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @AppStorage(AppLock.settingKey) private var lockOn = false
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @AppStorage(HealthService.stepsOnKey) private var healthStepsOn = false

    // UI only the questions and the notification state read on open
    @State private var notifications: AccessState = .notAsked
    @State private var isConfirmingClear = false
    @State private var isConfirmingDelete = false
    @State private var lockMessage: String?
    @State private var choosesPlanner = false

    var body: some View {
        let screen = SettingsScreen(plan: plans.first, now: AppClock.now())
        let settings = SettingsViewModel(plan: plans.first, now: AppClock.now())
        List {
            Section {
                permission("camera", "Camera", PermissionStates.camera)
                permission("bell", "Notifications", notifications)
                permission("calendar", "Calendar", PermissionStates.calendar)
                if settings.showsHealth { permission("heart", "Health", PermissionStates.health) }
            } header: {
                ListSectionHeader(title: screen.permissionsTitle)
            } footer: {
                Text(screen.permissionsFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                Toggle(isOn: Binding(get: { settings.planner.group != .onPhone && settings.planner.group != .yourMac },
                                     set: { isOn in
                    if isOn { choosesPlanner = true } else {
                        settings.choosePlanner(.onPhone)
                        plannerID = ModelChoice.onPhone.id.rawValue
                    }
                })) {
                    ListRow(symbol: "sparkles", title: screen.cloudToggle)
                }
                .tint(Color.accentFill)
                Toggle(isOn: lockBinding(settings)) {
                    ListRow(symbol: "lock", title: screen.lockToggle)
                }
                .tint(Color.accentFill)
                if settings.showsHealth {
                    Toggle(isOn: $healthStepsOn) {
                        ListRow(symbol: "figure.walk", title: screen.stepsToggle)
                    }
                    .tint(Color.accentFill)
                    .onChange(of: healthStepsOn) { _, isOn in settings.setHealthSteps(isOn) }
                }
                NavigationLink { HowPapersReadPage() } label: {
                    ListRow(symbol: "cpu", title: screen.howReadTitle,
                            subtitle: screen.plannerSubtitle(settings.planner.summaryName))
                }
                .id(plannerID)
            } footer: {
                Text(screen.privacyFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                Button(screen.clearChat, role: .destructive) { isConfirmingClear = true }
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                Button(screen.deleteAll, role: .destructive) { isConfirmingDelete = true }
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            }
        }
        .remedyList()
        .navigationTitle(screen.privacyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { notifications = await PermissionStates.notifications() }
        .navigationDestination(isPresented: $choosesPlanner) { ReaderChoiceView() }
        .confirmationDialog(screen.clearChat, isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button(screen.clearChat, role: .destructive) { settings.clearChat(in: context) }
        } message: {
            Text(screen.clearChatMessage)
        }
        .confirmationDialog(screen.deleteAll, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(screen.deleteAllAction, role: .destructive) {
                settings.clearChat(in: context)
                settings.deletePlan(in: context)
                closeSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(screen.deleteAllMessage)
        }
        .alert(settings.lockProblemTitle, isPresented: Binding(get: { lockMessage != nil }, set: { if !$0 { lockMessage = nil } })) {
            Button("OK") { lockMessage = nil }
        } message: {
            Text(lockMessage ?? "")
        }
    }

    // a permission row, tap opens ios settings
    private func permission(_ symbol: String, _ title: String, _ state: AccessState) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            ListRow(symbol: symbol, title: title, value: state.rawValue, showsChevron: true)
        }
        .buttonStyle(.plain)
    }

    // the lock only turns on once Face ID or the passcode worked
    private func lockBinding(_ settings: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { lockOn }, set: { isOn in
            guard isOn else { lockOn = false; return }
            Task {
                switch await settings.checkLockWorks() {
                case .verified: lockOn = true
                case .cancelled: break
                case .problem(let text): lockMessage = text
                }
            }
        })
    }
}

// MARK: - 64 How papers are read

// how papers are read, step by step
struct HowPapersReadPage: View {
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @AppStorage(ModelSettings.redactKey) private var hides = true
    @AppStorage(ModelSettings.sendsPhotosKey) private var sendsPictures = true
    @State private var store = LocalModelStore.shared

    var body: some View {
        let screen = SettingsScreen(plan: nil, now: AppClock.now())
        let planner = ModelChoice.choice(ModelChoice.ID(rawValue: plannerID) ?? .onPhone)
        let readsPhoto = planner.needsKey && sendsPictures
        List {
            Section {
                NavigationLink { ReadingPagePage() } label: {
                    ListRow(symbol: "camera", title: AIPagesWords.readingStep,
                            subtitle: readsPhoto ? AIPagesWords.readsPhoto(ProviderWords.shortName(planner)) : AIPagesWords.cameraText)
                }
                NavigationLink { NamesToHidePage() } label: {
                    ListRow(symbol: "eye.slash", title: AIPagesWords.hidingStep,
                            subtitle: hides ? AIPagesWords.hidingOn : AIPagesWords.hidingOff,
                            subtitleTone: hides ? .neutral : .caution)
                }
                NavigationLink { MakingPlanPage() } label: {
                    ListRow(symbol: "cpu", title: AIPagesWords.planStep,
                            subtitle: planner.id == .applePrivateCloud ? AIPagesWords.privateCloud
                                : (planner.id == .onPhone ? AIPagesWords.appleIntelligence : ProviderWords.shortName(planner)))
                }
            } footer: {
                Text(AIPagesWords.stepsFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                NavigationLink { NamesToHidePage() } label: {
                    ListRow(symbol: "eye.slash", title: screen.namesTitle,
                            subtitle: SettingsScreen.namesSubtitle(PatientNames.saved))
                }
                NavigationLink { DownloadedModelsPage() } label: {
                    ListRow(symbol: "arrow.down.circle", title: screen.modelsTitle, subtitle: LocalModelList.usedText(store))
                }
            }
        }
        .remedyList()
        .navigationTitle(screen.howReadTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 68 Names to hide

// the names hidden from every page
struct NamesToHidePage: View {
    @AppStorage(ModelSettings.redactKey) private var hides = true
    @State private var asksTurnOff = false
    // UI only the saved names and the one being typed
    @State private var names: [String] = PatientNames.saved
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        let screen = SettingsScreen(plan: nil, now: AppClock.now())
        List {
            Section {
                // turning it off asks first, 108
                Toggle(isOn: Binding(get: { hides }, set: { isOn in
                    if isOn { hides = true } else { asksTurnOff = true }
                })) {
                    ListRow(symbol: "eye.slash", title: AIPagesWords.hideToggle)
                }
                .tint(Color.accentFill)
                .confirmationDialog(AIPagesWords.hideOffTitle, isPresented: $asksTurnOff, titleVisibility: .visible) {
                    Button(AIPagesWords.turnOff, role: .destructive) { hides = false }
                    Button(AIPagesWords.keepOn, role: .cancel) {}
                } message: {
                    Text(AIPagesWords.hideOffMessage)
                }
            } footer: {
                Text(AIPagesWords.hideFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
            Section {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    ListRow(symbol: "person.crop.circle", title: name, subtitle: index == 0 ? screen.yourName : screen.otherSpelling)
                        .swipeActions {
                            Button(screen.removeName, role: .destructive) { remove(at: index) }
                        }
                }
                HStack(spacing: 14) {
                    RowIcon(symbol: "plus")
                    TextField(screen.addName, text: $draft)
                        .focused($isTyping)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onSubmit(add)
                }
                .frame(minHeight: Spacing.minTarget)
            } header: {
                ListSectionHeader(title: AIPagesWords.namesHeader)
            } footer: {
                Text(screen.namesFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.namesTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        names.append(clean)
        save()
        draft = ""
    }

    private func remove(at index: Int) {
        names.remove(at: index)
        save()
    }

    private func save() {
        PatientNames.save(names.joined(separator: "\n"))
    }
}

// MARK: - 71 Backup and restore

// make or restore a backup
struct BackupPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @AppStorage(SettingsScreen.lastBackupKey) private var lastBackup: Double = 0
    @State private var isMaking = false
    @State private var isRestoring = false

    var body: some View {
        let screen = SettingsScreen(plan: plans.first, now: AppClock.now())
        let settings = SettingsViewModel(plan: plans.first, now: AppClock.now())
        List {
            Section {
                if plans.first != nil {
                    Button { isMaking = true } label: {
                        ListRow(symbol: "square.and.arrow.up", title: screen.makeBackup, subtitle: screen.makeBackupSubtitle,
                                showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                Button { isRestoring = true } label: {
                    ListRow(symbol: "arrow.uturn.backward", title: screen.restoreBackup, subtitle: screen.restoreSubtitle,
                            showsChevron: true)
                }
                .buttonStyle(.plain)
            } footer: {
                Text(screen.backupFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.backupPageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .id(lastBackup)
        .sheet(isPresented: $isMaking) { MakeBackupView(viewModel: settings) }
        .sheet(isPresented: $isRestoring) { RestoreBackupView(viewModel: settings) }
    }
}

// MARK: - 75 About

// version, credits and the not a doctor note
struct AboutPage: View {
    var body: some View {
        let screen = SettingsScreen(plan: nil, now: AppClock.now())
        List {
            Section {
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Text(screen.appName).font(.title.bold()).foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity)
                .plainListRow()
            }
            Section {
                ListRow(symbol: "info.circle", title: screen.versionLabel, value: screen.versionText)
                ListRow(symbol: "person.crop.circle", title: screen.madeByLabel, subtitle: screen.madeBy)
                NavigationLink {
                    AcknowledgementsPage(title: screen.acknowledgements)
                } label: {
                    ListRow(symbol: "doc.text", title: screen.acknowledgements)
                }
            } footer: {
                Text(screen.aboutFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.aboutPageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// what Remedy is built with
enum AcknowledgementsText {
    static let body = "Remedy is built with Apple\u{2019}s SwiftUI, SwiftData, Vision, Foundation Models and MapKit. Sample papers and patients are made up."

    // 110 a heading and a line each
    static let blocks: [(title: String, text: String)] = [
        ("Icons", "SF Symbols by Apple."),
        ("Sample patients and test papers", "Made up by the Remedy team. No real patient data."),
        ("Open-source software", "Remedy uses the packages below, each under its own license."),
    ]
}

// each package's license, copied from the package into Resources/Licenses.json
struct PackageLicense: Decodable, Identifiable {
    let name: String
    let text: String
    var id: String { name }

    static let all: [PackageLicense] = {
        guard let url = Bundle.main.url(forResource: "Licenses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PackageLicense].self, from: data)) ?? []
    }()
}

// MARK: - 110 Acknowledgements

// open source licenses
struct AcknowledgementsPage: View {
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(AcknowledgementsText.blocks, id: \.title) { block in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title).font(.body.weight(.semibold)).foregroundStyle(Color.ink)
                        Text(block.text).font(.body).foregroundStyle(Color.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Spacing.insideCard)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(Spacing.screenEdge)
            VStack(spacing: 0) {
                ForEach(PackageLicense.all) { license in
                    NavigationLink {
                        ScrollView {
                            Text(license.text)
                                .font(.footnote.monospaced())
                                .foregroundStyle(Color.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.screenEdge)
                        }
                        .remedyBackground()
                        .navigationTitle(license.name)
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        ListRow(symbol: "doc.text", title: license.name, showsChevron: true)
                            .padding(.horizontal, Spacing.insideCard)
                    }
                    .buttonStyle(.plain)
                    if license.id != PackageLicense.all.last?.id { Divider().padding(.leading, 60) }
                }
            }
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .padding(.horizontal, Spacing.screenEdge)
        }
        .remedyBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
