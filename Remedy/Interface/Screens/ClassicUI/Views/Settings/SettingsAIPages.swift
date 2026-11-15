//
//  SettingsAIPages.swift
//  Remedy
//
//  making the plan (65), reading the page (105), your own ai key (106), add a key (107)
//  both looks open these from settings
//

import SwiftUI

// MARK: - 65 Making the plan

// who makes the plan
struct MakingPlanPage: View {
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @State private var keyVersion = 0

    var body: some View {
        let _ = keyVersion
        let settings = SettingsViewModel(plan: nil, now: AppClock.now())
        let keyed = AIPagesWords.keyProviders.map { ModelChoice.choice($0) }.filter(settings.hasKey)
        List {
            Section {
                RadioRow(title: AIPagesWords.appleIntelligence, subtitle: AIPagesWords.appleIntelligenceText,
                         isOn: plannerID == ModelChoice.ID.onPhone.rawValue) { pick(.onPhone, settings) }
                NavigationLink { DownloadedModelsPage() } label: {
                    ListRow(symbol: "arrow.down.circle", title: AIPagesWords.moreModels)
                }
            } header: {
                ListSectionHeader(title: AIPagesWords.onPhoneHeader)
            }
            Section {
                RadioRow(title: AIPagesWords.privateCloud, subtitle: AIPagesWords.privateCloudText,
                         isOn: plannerID == ModelChoice.ID.applePrivateCloud.rawValue,
                         isEnabled: settings.isSelectable(ModelChoice.choice(.applePrivateCloud))) {
                    pick(.applePrivateCloud, settings)
                }
                // a provider with a saved key is a choice here
                ForEach(keyed, id: \.id) { choice in
                    RadioRow(title: ProviderWords.shortName(choice), subtitle: AIPagesWords.keySavedChoice,
                             isOn: plannerID == choice.id.rawValue) { pick(choice.id, settings) }
                }
                NavigationLink { OwnKeyPage() } label: {
                    ListRow(symbol: "key", title: AIPagesWords.ownKey, subtitle: AIPagesWords.ownKeyText)
                }
            } header: {
                ListSectionHeader(title: AIPagesWords.cloudHeader)
            }
            Section {
                NavigationLink { MacPage() } label: {
                    ListRow(symbol: "desktopcomputer", title: AIPagesWords.connectMac, subtitle: AIPagesWords.connectMacText)
                }
            } header: {
                ListSectionHeader(title: AIPagesWords.macHeader)
            } footer: {
                Text(AIPagesWords.planFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(AIPagesWords.planTitle)
        .navigationBarTitleDisplayMode(.inline)
        // coming back from the keys page reads the keys again, without a new identity that would loop
        .onAppear { keyVersion += 1 }
    }

    private func pick(_ id: ModelChoice.ID, _ settings: SettingsViewModel) {
        let choice = ModelChoice.choice(id)
        settings.choosePlanner(choice)
        plannerID = choice.id.rawValue
    }
}

// the downloaded models, kept from before inside its own page
struct DownloadedModelsPage: View {
    @State private var store = LocalModelStore.shared

    var body: some View {
        List { LocalModelList(store: store).plainListRow() }
            .remedyList()
            .navigationTitle(SettingsScreen(plan: nil, now: AppClock.now()).modelsTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// your own mac on the same wi-fi, the connection panel kept from before
struct MacPage: View {
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue

    var body: some View {
        List {
            Section {
                RadioRow(title: AIPagesWords.useMac, isOn: plannerID == ModelChoice.ID.yourMac.rawValue) {
                    SettingsViewModel(plan: nil, now: AppClock.now()).choosePlanner(ModelChoice.choice(.yourMac))
                    plannerID = ModelChoice.ID.yourMac.rawValue
                }
            }
            Section {
                MacConnectionPanel().plainListRow()
            }
        }
        .remedyList()
        .navigationTitle(AIPagesWords.connectMac)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 105 Reading the page

// who reads the page
struct ReadingPagePage: View {
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @AppStorage(ModelSettings.sendsPhotosKey) private var sendsPictures = true

    @State private var readingID = ModelSettings.load().readingChoice.rawValue

    // the page text reader, picking one stops sending photos
    private func pickReader(_ id: String) {
        sendsPictures = false
        var setup = ReaderSetupViewModel.live(ModelSettings.load())
        guard setup.pick(id, in: .page) else { return }
        setup.settings.sendTextOnly = true
        setup.settings.save()
        readingID = id
    }

    // only cloud ais that read photos and take a key
    private static let photoReaders: [ModelChoice.ID] = [.claude, .gemini]

    var body: some View {
        let settings = SettingsViewModel(plan: nil, now: AppClock.now())
        let planner = ModelChoice.choice(ModelChoice.ID(rawValue: plannerID) ?? .onPhone)
        let photoOn = planner.needsKey && sendsPictures
        List {
            Section {
                RadioRow(title: AIPagesWords.cameraText, subtitle: AIPagesWords.cameraDetail,
                         isOn: !photoOn && readingID == ReadingChoice.camera.rawValue) { pickReader(ReadingChoice.camera.rawValue) }
                // downloaded readers and apple's cloud, off with the reason until ready
                ForEach(ReaderSetupViewModel.live(ModelSettings.load()).pageCards.filter { $0.id != ReadingChoice.camera.rawValue }) { card in
                    RadioRow(title: card.title, subtitle: card.detail, isOn: !photoOn && readingID == card.id,
                             isEnabled: card.isReady) { pickReader(card.id) }
                }
                ForEach(Self.photoReaders, id: \.self) { id in
                    let choice = ModelChoice.choice(id)
                    let name = ProviderWords.shortName(choice)
                    let hasKey = settings.hasKey(choice)
                    RadioRow(title: AIPagesWords.readsPhoto(name),
                             subtitle: hasKey ? AIPagesWords.usesKey(name) : AIPagesWords.addKeyFirst(name),
                             isOn: photoOn && planner.id == id, isEnabled: hasKey) {
                        settings.choosePlanner(choice)
                        plannerID = choice.id.rawValue
                        sendsPictures = true
                    }
                }
            } footer: {
                Text(AIPagesWords.readingFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(AIPagesWords.readingTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 106 Your own AI key

// the patient's own ai keys
struct OwnKeyPage: View {
    @State private var editing: ModelChoice?
    @State private var version = 0

    var body: some View {
        let settings = SettingsViewModel(plan: nil, now: AppClock.now())
        List {
            Section {
                ForEach(AIPagesWords.keyProviders, id: \.self) { id in
                    let choice = ModelChoice.choice(id)
                    let saved = settings.hasKey(choice)
                    Button { editing = choice } label: {
                        ListRow(symbol: "key", tone: saved ? .info : .neutral, title: ProviderWords.shortName(choice),
                                subtitle: saved ? AIPagesWords.keySaved
                                    : (id == .openAICompatible ? AIPagesWords.customAddress : AIPagesWords.noKey),
                                showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(AIPagesWords.keysFooter).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .id(version)
        .navigationTitle(AIPagesWords.keysTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing, onDismiss: { version += 1 }) { choice in
            AddKeySheet(choice: choice)
        }
    }
}

// MARK: - 107 Add a key

// paste a key, test it and save it to the keychain
struct AddKeySheet: View {
    let choice: ModelChoice

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var check = KeyCheck.idle
    @State private var asksRemove = false
    @AppStorage private var modelName: String
    @AppStorage private var address: String
    @AppStorage private var isFree: Bool

    init(choice: ModelChoice) {
        self.choice = choice
        _isFree = AppStorage(wrappedValue: false, AIPagesWords.freeKey(choice))
        _modelName = AppStorage(wrappedValue: "", OpenAICompatibleAdapter.modelKey(for: choice))
        _address = AppStorage(wrappedValue: "", OpenAICompatibleAdapter.addressKey(for: choice))
    }

    private var settings: SettingsViewModel { SettingsViewModel(plan: nil, now: AppClock.now()) }

    var body: some View {
        let saved = settings.hasKey(choice)
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Text(AIPagesWords.keyLabel).foregroundStyle(Color.ink2)
                        SecureField(AIPagesWords.keyLabel, text: $key,
                                    prompt: Text(saved ? "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}" : AIPagesWords.keyPrompt))
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .frame(minHeight: Spacing.minTarget)
                    if choice.asksAddress {
                        NavigationLink {
                            TextFieldPage(title: AIPagesWords.addressLabel, text: $address, prompt: "https://")
                        } label: {
                            ListRow(symbol: "link", title: AIPagesWords.addressLabel,
                                    value: address.isEmpty ? AIPagesWords.pickModel : address)
                        }
                    }
                    if !ProviderModels.options(choice.id).isEmpty {
                        NavigationLink { ProviderModelPage(choice: choice) } label: {
                            ListRow(symbol: "cpu", title: AIPagesWords.modelLabel,
                                    value: ProviderModels.options(choice.id).first { $0.id == ProviderModels.picked(choice.id) }?.title ?? "")
                        }
                    }
                    if choice.usesCompatibleAdapter {
                        NavigationLink {
                            TextFieldPage(title: AIPagesWords.modelLabel, text: $modelName, prompt: choice.defaultModel)
                        } label: {
                            ListRow(symbol: "cpu", title: AIPagesWords.modelLabel,
                                    value: modelName.isEmpty ? AIPagesWords.pickModel : modelName)
                        }
                    }
                    Toggle(isOn: $isFree) { ListRow(symbol: "gift", title: AIPagesWords.freeToggle) }
                        .tint(Color.accentFill)
                } footer: {
                    if isFree { Text(AIPagesWords.freeFooter).font(.footnote).foregroundStyle(Color.ink2) }
                }
                checkSection
                Section {
                    VStack(spacing: 12) {
                        PrimaryButton(title: AIPagesWords.saveKey) { save() }
                            .disabled(!settings.canSave(key, for: choice))
                        SecondaryButton(title: AIPagesWords.checkKey) { Task { await runCheck() } }
                            .disabled(!saved && !settings.canSave(key, for: choice))
                    }
                    .plainListRow()
                }
                if saved {
                    Section {
                        Button(AIPagesWords.removeKey, role: .destructive) { asksRemove = true }
                            .frame(maxWidth: .infinity)
                            .confirmationDialog(AIPagesWords.removeAsk, isPresented: $asksRemove, titleVisibility: .visible) {
                                Button(AIPagesWords.removeKey, role: .destructive) {
                                    settings.removeKey(for: choice)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                    }
                }
            }
            .remedyList()
            .navigationTitle(ProviderWords.shortName(choice))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var checkSection: some View {
        switch check {
        case .idle: EmptyView()
        case .checking:
            Section {
                HStack(spacing: 12) { ProgressView(); Text(AIPagesWords.checking) }
                    .frame(minHeight: Spacing.minTarget)
            }
        case .works(let seconds):
            Section {
                ListRow(symbol: "checkmark.circle", tone: .good, title: AIPagesWords.keyWorks,
                        subtitle: AIPagesWords.keyWorksText(seconds))
                    .toneRow(.good)
            }
        case .refused, .offline:
            Section {
                ListRow(symbol: "exclamationmark.triangle", tone: .caution,
                        title: check == .offline ? AIPagesWords.offline : AIPagesWords.refused)
                    .toneRow(.caution)
            }
        }
    }

    private func save() {
        settings.saveKey(key, for: choice)
        key = ""
        dismiss()
    }

    // reads one fake sample page with the typed or saved key, never patient data
    private func runCheck() async {
        // a typed key is only kept if it works, Save Key keeps it for good
        let wasSaved = settings.hasKey(choice)
        let triesTyped = settings.canSave(key, for: choice)
        if triesTyped { settings.saveKey(key, for: choice) }
        check = .checking
        let start = Date()
        do {
            _ = try await PlanReaders.reader(for: choice).readPlan(from: [AIPagesWords.samplePage], pictures: [nil],
                                                                  paper: .afterSurgery)
            check = .works(seconds: max(1, Int(Date().timeIntervalSince(start).rounded())))
        } catch {
            check = KeyCheck.from(error)
            if triesTyped && !wasSaved { settings.removeKey(for: choice) }
        }
    }
}

// the fixed model list for claude or gemini
struct ProviderModelPage: View {
    let choice: ModelChoice
    @AppStorage private var picked: String

    init(choice: ModelChoice) {
        self.choice = choice
        _picked = AppStorage(wrappedValue: ProviderModels.picked(choice.id), ProviderModels.key(choice.id))
    }

    var body: some View {
        List {
            ForEach(ProviderModels.options(choice.id), id: \.id) { option in
                RadioRow(title: option.title, isOn: picked == option.id) { picked = option.id }
            }
        }
        .remedyList()
        .navigationTitle(AIPagesWords.modelLabel)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ModelChoice: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
