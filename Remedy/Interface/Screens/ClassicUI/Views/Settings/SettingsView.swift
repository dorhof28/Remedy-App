//
//  SettingsView.swift
//  Remedy
//
//  classic settings
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// classic settings sheet
struct SettingsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    // only here so the row values redraw when they change
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @AppStorage(AppLookMode.storageKey) private var lookMode: AppLookMode = .automatic
    @AppStorage(LaunchOptions.demoModeKey) private var demoOn = false
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .remedy
    // UI only the theme tapped here saved when Settings closes so this sheet stays open
    @State private var pickedTheme: AppTheme?
    @State private var isShowingDemo = false

    var body: some View {
        let screen = SettingsScreen(plan: plans.first, now: AppClock.now())
        NavigationStack {
            List {
                Section {
                    NavigationLink { RemindersPage() } label: {
                        ListRow(symbol: "bell", title: screen.remindersTitle, value: screen.remindersValue)
                    }
                }
                Section {
                    Picker(screen.lookTitle, selection: $lookMode) {
                        ForEach(AppLookMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .plainListRow()
                    // no Colors row until Dorron decides on themes, the old page is kept
                } header: {
                    ListSectionHeader(title: screen.lookTitle)
                } footer: {
                    Text(screen.lookFooter).font(.footnote).foregroundStyle(Color.ink2)
                }
                Section {
                    NavigationLink { PrivacyPage(closeSettings: { dismiss() }) } label: {
                        ListRow(symbol: "lock", title: screen.privacyTitle)
                    }
                    if plans.first?.surgeryDate != nil {
                        NavigationLink { SurgeryView() } label: {
                            ListRow(symbol: "calendar", title: screen.surgeryTitle, subtitle: screen.surgerySubtitle)
                        }
                    }
                    if plans.first != nil {
                        NavigationLink { PapersView() } label: {
                            ListRow(symbol: "doc.text", title: screen.papersTitle, subtitle: screen.papersSubtitle)
                        }
                    }
                    NavigationLink { BackupPage() } label: {
                        ListRow(symbol: "arrow.uturn.backward", title: screen.backupTitle, subtitle: screen.backupSubtitle)
                    }
                    Button { isShowingDemo = true } label: {
                        ListRow(symbol: "sparkles", title: screen.demoTitle, value: screen.demoValue, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    NavigationLink { AboutPage() } label: {
                        ListRow(symbol: "info.circle", title: screen.aboutTitle)
                    }
                } footer: {
                    Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .navigationTitle(screen.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                if let pickedTheme { theme = pickedTheme }
            }
            .sheet(isPresented: $isShowingDemo) { DemoModeView() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(screen.doneTitle) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Backup (both looks open these, big text and one step at a time)

// the locked file handed to Files
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

// pick a password and save a locked backup file
struct MakeBackupView: View {

    let viewModel: SettingsViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // UI only typed passwords and where the steps are
    @State private var password = ""
    @State private var again = ""
    @State private var isWorking = false
    @State private var document: BackupDocument?
    @State private var isSaved = false
    @State private var message: String?
    private enum Field { case first, second }
    @FocusState private var focus: Field?

    var body: some View {
        let problem = viewModel.backupPasswordProblem(password, again: again)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isSaved {
                        Label(viewModel.backupSavedText, systemImage: "checkmark.circle.fill")
                            .font(.title3.bold())
                        Button(viewModel.doneTitle) { dismiss() }
                            .bigBackupButton()
                    } else {
                        Text(viewModel.backupPasswordIntro)
                        SecureField(viewModel.passwordPrompt, text: $password)
                            .backupField()
                            .textContentType(.newPassword)
                            .submitLabel(.next)
                            .focused($focus, equals: .first)
                            .onSubmit { focus = .second }
                        SecureField(viewModel.passwordAgainPrompt, text: $again)
                            .backupField()
                            .textContentType(.newPassword)
                            .submitLabel(.done)
                            .focused($focus, equals: .second)
                            .onSubmit { focus = nil }
                        // only nags once both are typed
                        if let problem, !again.isEmpty {
                            Text(problem).foregroundStyle(Color.dangerInk)
                        }
                        if let message {
                            Text(message).foregroundStyle(Color.dangerInk)
                        }
                        Button {
                            Task { await lock() }
                        } label: {
                            if isWorking { ProgressView() } else { Text(viewModel.lockBackupTitle) }
                        }
                        .bigBackupButton()
                        .disabled(problem != nil || isWorking)
                    }
                }
                .font(.title3)
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.makeBackupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.cancelTitle) { dismiss() }
                }
            }
            .fileExporter(isPresented: Binding(get: { document != nil }, set: { if !$0 { document = nil } }),
                          document: document, contentType: .data,
                          defaultFilename: BackupFile.fileName(on: AppClock.now())) { result in
                if case .success = result { isSaved = true }
            }
        }
    }

    private func lock() async {
        isWorking = true
        message = nil
        do {
            document = BackupDocument(data: try await viewModel.makeBackup(password: password, in: context))
        } catch {
            message = viewModel.backupErrorText(error)
        }
        isWorking = false
    }
}

private extension View {
    func bigBackupButton(tint: Color = .accentFill) -> some View {
        self.font(.title3.bold())
            .buttonStyle(.borderedProminent)
            .buttonSizing(.flexible)
            .controlSize(.large)
            .tint(tint)
    }

    func backupField() -> some View {
        self.textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

// MARK: - Who reads your papers (both looks open this list)

// picks who makes the plan
struct ReaderChoiceView: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @AppStorage(ModelSettings.redactKey) private var hides = true
    @AppStorage(ModelSettings.sendsPhotosKey) private var sendsPictures = true

    // UI only the typed key and a counter to redraw once it is saved
    @State private var keyDraft = ""
    @State private var keyVersion = 0
    @State private var isConfirmingHideOff = false

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SettingsScroll {
            Text(viewModel.readerIntro)
                .font(.subheadline)
                .foregroundStyle(Color.ink2)
                .padding(.horizontal, 16)

            ForEach(viewModel.readerGroups) { group in
                SettingsSection {
                    OptionCardList(items: group.choices.map { choice in
                        OptionCardItem(id: choice.id.rawValue, symbol: viewModel.readerSymbol(choice), title: choice.displayName,
                                       subtitle: viewModel.readerSubtitle(choice), isEnabled: viewModel.isSelectable(choice))
                    }, selection: plannerID, look: .classic, onPick: { id in
                        guard let choice = ModelChoice.all.first(where: { $0.id.rawValue == id }) else { return }
                        viewModel.choosePlanner(choice)
                        plannerID = choice.id.rawValue
                    }, below: { item in
                        if let choice = ModelChoice.all.first(where: { $0.id.rawValue == item.id }),
                           choice.needsKey || choice.usesCompatibleAdapter {
                            keyFields(choice, viewModel)
                        }
                    })
                    if group.showsTextOnly {
                        SettingsToggleRow(symbol: "text.alignleft", title: viewModel.textOnlyToggle,
                                          isOn: Binding(get: { !sendsPictures }, set: { sendsPictures = !$0 }))
                    }
                } header: {
                    Text(group.title)
                } footer: {
                    if group.showsTextOnly { Text(viewModel.textOnlyFooter) }
                }
            }

            SettingsSection {
                SettingsToggleRow(symbol: "eye.slash.fill", title: viewModel.hideToggle, isOn: Binding(get: { hides }, set: { isOn in
                    if !isOn && viewModel.confirmsTurningOffHiding {
                        isConfirmingHideOff = true
                    } else {
                        hides = isOn
                    }
                }))
            } footer: {
                Text(viewModel.hideFooter)
            }
        }
        .navigationTitle(viewModel.readerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.doneTitle) { dismiss() }
            }
        }
        .alert(viewModel.hideOffTitle, isPresented: $isConfirmingHideOff) {
            Button(viewModel.hideOffButton, role: .destructive) { hides = false }
            Button(viewModel.hideKeepButton, role: .cancel) {}
        } message: {
            Text(viewModel.hideOffMessage)
        }
    }

    // what the picked reader needs: its address, model name and key
    private func keyFields(_ choice: ModelChoice, _ viewModel: SettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if choice.usesCompatibleAdapter {
                CompatibleFields(choice: choice, viewModel: viewModel)
            }
            if choice.needsKey && viewModel.hasKey(choice) {
                Label(viewModel.keySavedText, systemImage: "key.fill")
                    .font(.subheadline)
                Button(viewModel.removeKeyTitle, role: .destructive) {
                    viewModel.removeKey(for: choice)
                    keyVersion += 1
                }
                .buttonStyle(.bordered)
            } else if choice.needsKey {
                SecureField(viewModel.keyPrompt, text: $keyDraft)
                    .textContentType(.password)
                    .submitLabel(.done)
                    .onSubmit {
                        guard viewModel.canSave(keyDraft, for: choice) else { return }
                        viewModel.saveKey(keyDraft, for: choice)
                        keyDraft = ""
                        keyVersion += 1
                    }
                Button(viewModel.saveKeyTitle) {
                    viewModel.saveKey(keyDraft, for: choice)
                    keyDraft = ""
                    keyVersion += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSave(keyDraft, for: choice))
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .id(keyVersion)
    }
}

// model name and address of an openai compatible choice each choice keeps its own
private struct CompatibleFields: View {

    let choice: ModelChoice
    let viewModel: SettingsViewModel
    @AppStorage private var address: String
    @AppStorage private var modelName: String

    init(choice: ModelChoice, viewModel: SettingsViewModel) {
        self.choice = choice
        self.viewModel = viewModel
        _address = AppStorage(wrappedValue: "", OpenAICompatibleAdapter.addressKey(for: choice))
        _modelName = AppStorage(wrappedValue: "", OpenAICompatibleAdapter.modelKey(for: choice))
    }

    var body: some View {
        if choice.id == .yourMac {
            MacConnectionPanel()
                .padding(Spacing.insideCard)
                .cardStyle()
        } else if choice.asksAddress {
            TextField(choice.id == .yourMac ? viewModel.macPrompt : viewModel.urlPrompt, text: $address)
                .keyboardType(.URL)
                .textContentType(.URL)
                .submitLabel(.next)
        }
        if choice.id != .yourMac {
            TextField(choice.defaultModel.isEmpty ? viewModel.modelPrompt : "\(viewModel.modelPrompt): \(choice.defaultModel)", text: $modelName)
                .submitLabel(.done)
        }
    }
}

#Preview(traits: .beforeSurgerySample) {
    SettingsView()
}
