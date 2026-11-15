//
//  SimpleSettingsPages.swift
//  Remedy
//
//  simple settings screens, one thing at a time
//

import SwiftUI
import SwiftData

// MARK: - Shared bits

// big switch with an icon and one plain line under it
struct SimpleToggleCard: View {
    let title: String
    let symbol: String
    var note: String = ""
    var noteIsWarning = false
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isOn) {
                Label(title, systemImage: symbol)
                    .font(.title3.bold())
            }
            .tint(Color.accentFill)
            .frame(minHeight: Spacing.minTarget)
            if !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(noteIsWarning ? Tone.stop.color : Color.ink2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsCardStyle()
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

// MARK: - Reminders

// simple reminders page
struct SimpleRemindersPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @AppStorage(CalendarService.planOnKey) private var calendarOn = false
    @AppStorage(LastDoseQuestion.settingKey) private var asksLastDose = false
    @Environment(\.modelContext) private var context
    @State private var calendarMessage: String?
    @State private var editsCheckInTime = false

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        let checkIn = CheckInViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.remindersTitle) {
            SimpleToggleCard(title: viewModel.simpleRemindersTitle, symbol: "bell.fill", isOn: $remindersOn)
                .onChange(of: remindersOn) { _, isOn in viewModel.setReminders(isOn) }
            if plans.first != nil {
                Button { editsCheckInTime = true } label: {
                    SimpleRowCard(title: "Daily check-in time",
                                  subtitle: checkIn.checkInMinute.map { CheckInTime.text(minute: $0) } ?? "Not set") {
                        Image(systemName: "heart.text.clipboard").font(.title).foregroundStyle(Color.accentInk)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-checkin-time")
            }
            SimpleToggleCard(title: viewModel.lastDoseToggle, symbol: "questionmark.bubble.fill",
                             note: viewModel.lastDoseFooter, isOn: $asksLastDose)
            if viewModel.hasSurgeryDate {
                SimpleToggleCard(title: viewModel.calendarToggle, symbol: "calendar",
                                 note: calendarMessage ?? "", noteIsWarning: true, isOn: $calendarOn)
                    .onChange(of: calendarOn) { _, isOn in
                        Task {
                            calendarMessage = await viewModel.setCalendar(isOn)
                            if isOn, calendarMessage != nil { calendarOn = false }
                        }
                    }
            }
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $editsCheckInTime) {
            CheckInTimeSheet(current: checkIn.checkInMinute, startsLater: checkIn.day < 0, simple: true,
                             onSave: { checkIn.setTime($0, in: context); editsCheckInTime = false },
                             onNotNow: { editsCheckInTime = false },
                             onRemove: { checkIn.setTime(nil, in: context); editsCheckInTime = false })
        }
    }
}

// MARK: - Privacy and security

// simple privacy and lock page
struct SimplePrivacyPage: View {
    @AppStorage(AppLock.settingKey) private var lockOn = false
    @State private var lockMessage: String?

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SimpleScreen(title: viewModel.privacySecurityTitle) {
            SimpleToggleCard(title: viewModel.lockToggle, symbol: "faceid",
                             note: lockMessage ?? viewModel.lockFooter, noteIsWarning: lockMessage != nil,
                             isOn: lockBinding(viewModel))
            Label(viewModel.privacyText, systemImage: "lock.shield.fill")
                .font(.body)
                .foregroundStyle(Color.ink2)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsCardStyle()
            Spacer(minLength: 0)
        }
    }

    // the lock only turns on once Face ID or the passcode worked
    private func lockBinding(_ viewModel: SettingsViewModel) -> Binding<Bool> {
        Binding(get: { lockOn }, set: { isOn in
            lockMessage = nil
            guard isOn else { lockOn = false; return }
            Task {
                switch await viewModel.checkLockWorks() {
                case .verified: lockOn = true
                case .cancelled: break
                case .problem(let text): lockMessage = text
                }
            }
        })
    }
}

// MARK: - Reading and AI

// simple reading and ai page
struct SimpleReadingPage: View {
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SimpleScreen(title: viewModel.readingTitle) {
            Text(viewModel.leavesFooter)
                .font(.body)
                .foregroundStyle(Color.ink2)
            AIChoiceView()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsCardStyle()
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Plan

// simple your plan page
struct SimplePlanPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.surgeryTitle) {
            if viewModel.hasPlan {
                VStack(alignment: .leading, spacing: 4) {
                    DatePicker(selection: Binding(get: { viewModel.surgeryDate },
                                                  set: { viewModel.setSurgeryDate($0, in: context) }),
                               displayedComponents: .date) {
                        Label(viewModel.surgeryDateLabel, systemImage: "calendar.badge.clock")
                            .font(.title3.bold())
                    }
                    .frame(minHeight: Spacing.minTarget)
                    Text(viewModel.dateFootnote)
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .settingsCardStyle()
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Appearance

// simple look and colors page
struct SimpleAppearancePage: View {
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .remedy
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SimpleScreen(title: viewModel.appearanceTitle) {
            VStack(alignment: .leading, spacing: 10) {
                Label(viewModel.themeTitle, systemImage: "paintpalette.fill")
                    .font(.title3.bold())
                ThemePicker(theme: $theme, look: .simple)
            }

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Motion.perform(reduceMotion) { look = .classic }
                } label: {
                    Label(viewModel.switchToClassicTitle, systemImage: "rectangle.grid.1x2.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
                Text(viewModel.switchToClassicFooter)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Your data

// simple backup and data page
struct SimpleDataPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @State private var isMakingBackup = false
    @State private var isRestoringBackup = false
    @State private var isConfirmingClearChat = false
    @State private var isConfirmingDeletePlan = false

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.dataTitle) {
            if viewModel.hasPlan {
                Button {
                    isMakingBackup = true
                } label: {
                    Label(viewModel.makeBackupTitle, systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(SimpleButtonStyle(kind: .primary))
            }
            Button {
                isRestoringBackup = true
            } label: {
                Label(viewModel.restoreBackupTitle, systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain))

            Text(viewModel.backupFooter)
                .font(.body)
                .foregroundStyle(Color.ink2)

            Spacer(minLength: 0)

            Button(viewModel.clearChatTitle) { isConfirmingClearChat = true }
                .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
            if viewModel.hasPlan {
                Button(viewModel.deletePlanTitle) { isConfirmingDeletePlan = true }
                    .buttonStyle(SimpleButtonStyle(kind: .danger, height: 56))
            }
        }
        .sheet(isPresented: $isMakingBackup) { MakeBackupView(viewModel: viewModel) }
        .sheet(isPresented: $isRestoringBackup) { RestoreBackupView(viewModel: viewModel) }
        .confirmationDialog(viewModel.clearChatTitle, isPresented: $isConfirmingClearChat, titleVisibility: .visible) {
            Button(viewModel.clearChatTitle, role: .destructive) { viewModel.clearChat(in: context) }
        } message: {
            Text(viewModel.clearChatMessage)
        }
        .confirmationDialog(viewModel.deletePlanTitle, isPresented: $isConfirmingDeletePlan, titleVisibility: .visible) {
            Button(viewModel.deletePlanTitle, role: .destructive) { viewModel.deletePlan(in: context) }
        } message: {
            Text(viewModel.deletePlanMessage)
        }
    }
}

// MARK: - About

// simple about page
struct SimpleAboutPage: View {
    // UI only is the full list of settings open, 
    @State private var isShowingAll = false

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SimpleScreen(title: viewModel.aboutTitle) {
            BrandFooter(motto: viewModel.motto, large: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(viewModel.versionLabel) \(viewModel.versionText)")
                    .font(.title3.weight(.semibold))
                Text("\(viewModel.creditsLabel) \(viewModel.creditsText)")
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsCardStyle()

            Text(viewModel.disclaimer)
                .font(.body)
                .foregroundStyle(Color.ink2)

            Spacer(minLength: 0)

            Button {
                isShowingAll = true
            } label: {
                Label(viewModel.advancedTitle, systemImage: "gearshape.fill")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
        }
        .sheet(isPresented: $isShowingAll) { SettingsView() }
    }
}

// MARK: - Demo

// simple demo mode page
struct SimpleDemoSettingsPage: View {
    @Environment(\.modelContext) private var context
    @AppStorage(LaunchOptions.demoModeKey) private var demoOn = false
    // UI only the demo sheet, the exit question and a problem message
    @State private var isShowingDemo = false
    @State private var isConfirmingExit = false
    @State private var message: String?

    var body: some View {
        let demo = DemoModeViewModel()
        SimpleScreen(title: demo.screenTitle) {
            SimpleToggleCard(title: demo.toggleTitle, symbol: "flask.fill", note: demo.toggleNote, isOn: demoBinding(demo))
            if demoOn {
                Button {
                    isShowingDemo = true
                } label: {
                    Label(demo.openTitle, systemImage: "person.crop.circle.badge.questionmark")
                }
                .buttonStyle(SimpleButtonStyle(kind: .primary, height: 64))
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $isShowingDemo) { DemoModeView() }
        .confirmationDialog(demo.exitTitle, isPresented: $isConfirmingExit, titleVisibility: .visible) {
            Button(demo.exitTitle, role: .destructive) {
                Task {
                    do { try await demo.exit(in: context) } catch { message = demo.errorText(error) }
                }
            }
            Button(demo.cancelTitle, role: .cancel) {}
        } message: {
            Text(demo.exitMessage)
        }
        .alert(demo.screenTitle, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // on opens the picker, off brings the real plan back first if a fake one replaced it
    private func demoBinding(_ demo: DemoModeViewModel) -> Binding<Bool> {
        Binding(get: { demoOn }, set: { isOn in
            if isOn {
                demo.turnOn()
                isShowingDemo = true
            } else if demo.hasSavedPlan {
                isConfirmingExit = true
            } else {
                demo.turnOffWithoutPlan()
            }
        })
    }
}

// MARK: - Papers

// the papers that were added, three to a page, with Remove and Add
struct SimplePapersPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    // UI only the add sheet and the paper being removed
    @State private var isScanningMore = false
    @State private var paperToRemove: Paper?

    var body: some View {
        let plan = plans.first
        let viewModel = PapersSettingsViewModel(plan: plan)
        SimpleScreen(title: viewModel.title) {
            if viewModel.papers.isEmpty {
                Text(viewModel.emptyTitle)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            } else {
                SimplePagedList(items: viewModel.papers, perPage: 3) { paper in
                    paperRow(paper, viewModel)
                }
            }
            // only when a newer paper changed something
            if WhatChangedViewModel(plan: plan) != nil {
                NavigationLink { SimpleWhatChangedPage() } label: {
                    Label(WhatChangedViewModel.planRowTitle, systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SimpleButtonStyle(kind: .gray, height: 64))
            }
            if viewModel.hasPlan {
                Text(viewModel.addFooter)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                Button {
                    isScanningMore = true
                } label: {
                    Label(viewModel.addTitle, systemImage: "plus")
                }
                .buttonStyle(SimpleButtonStyle(height: 64))
            }
        }
        .sheet(isPresented: $isScanningMore) {
            ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plan?.surgeryDate != nil)
        }
        .confirmationDialog(viewModel.removeTitle, isPresented: Binding(get: { paperToRemove != nil }, set: { if !$0 { paperToRemove = nil } }),
                            titleVisibility: .visible, presenting: paperToRemove) { paper in
            Button(viewModel.removeTitle, role: .destructive) {
                if let plan { PaperActions.remove(paper, from: plan, in: context) }
            }
        } message: { paper in
            Text(viewModel.removeMessage(for: paper))
        }
    }

    private func paperRow(_ paper: Paper, _ viewModel: PapersSettingsViewModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.rowTitle(paper))
                    .font(.title3.bold())
                Text(viewModel.rowDetail(paper))
                    .font(.body)
                    .foregroundStyle(Color.ink2)
            }
            Spacer(minLength: 8)
            Button {
                paperToRemove = paper
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .frame(minWidth: 56, minHeight: 56)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.dangerInk)
            .accessibilityLabel("\(viewModel.removeTitle) \(viewModel.rowTitle(paper))")
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
    }
}
