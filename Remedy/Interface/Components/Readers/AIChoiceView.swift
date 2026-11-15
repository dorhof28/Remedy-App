//
//  AIChoiceView.swift
//  Remedy
//
//  what reads the page, what hides names and what makes the plan, one line each and a Change button
//  shown before papers are sent and ready to sit in Settings
//

import SwiftUI

// picks who reads the page, who hides names and who makes the plan
struct AIChoiceView: View {
    var defaults: UserDefaults = .standard
    // told after every change so the caller can reload its copy
    var onChange: (ModelSettings) -> Void = { _ in }
    // the scan flow puts Change in the top bar and opens the sheet itself
    var showsChangeButton: Bool = true
    // bumped by the caller after a change so the lines reload
    var reloadToken: Int = 0

    @State private var settings = ModelSettings()
    @State private var ownSheet = false
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    private var isSimple: Bool { look == .simple }

    private var lines: AIChoiceLines {
        AIChoiceLines.make(settings, problem: AIChoiceView.problem(settings))
    }

    var body: some View {
        let lines = lines
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                row(lines.page, symbol: ReaderStep.page.symbol)
                row(lines.hiding, symbol: ReaderStep.hiding.symbol)
                row(lines.reading, symbol: ReaderStep.plan.symbol)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChangeButton {
                Button("Change") { ownSheet = true }
                    .buttonStyle(.borderless)
                    .font((isSimple ? Font.body : .subheadline).weight(.semibold))
                    .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                    .accessibilityLabel("Change how your papers are read")
            }
        }
        .onAppear { settings = ModelSettings.load(from: defaults) }
        .onChange(of: reloadToken) { settings = ModelSettings.load(from: defaults) }
        .sheet(isPresented: $ownSheet, onDismiss: { settings = ModelSettings.load(from: defaults) }) {
            AIChoiceSheet(defaults: defaults) { changed in
                settings = changed
                onChange(changed)
            }
        }
    }

    // one plain line with a small icon, a red second line when not ready
    private func row(_ line: AIChoiceLine, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, tone: line.problem == nil ? .info : .stop, size: isSimple ? 30 : 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.text)
                    .font(isSimple ? .body : .subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let problem = line.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .font((isSimple ? Font.callout : .footnote).weight(.semibold))
                        .foregroundStyle(Tone.stop.color)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // the first pick that cannot be used right now
    static func problem(_ settings: ModelSettings) -> AIProblem? {
        settings.problem(phoneAIReady: isReady(settings.redactionChoice),
                         pageReaderReady: PageModelReader.isReady(settings.readingChoice),
                         readerReady: isReady(settings.plannerChoice))
    }

    // a model off the phone counts as ready once its key or address is saved
    static func isReady(_ choice: ModelChoice) -> Bool {
        if LaunchOptions.usesFakeAI { return true }
        return PlanReaders.reader(for: choice).isAvailable
    }

    // rules only needs no download so it is always ready
    static func isReady(_ choice: RedactionChoice) -> Bool {
        choice == .rulesOnly || LaunchOptions.usesFakeAI || PersonalInfoFinders.finder(for: choice).isAvailable
    }
}

// the sheet with the three steps and the models on this iphone
// classic is a list of the three steps, each opening its own page, simple asks one step per screen
struct AIChoiceSheet: View {
    let defaults: UserDefaults
    let onChange: (ModelSettings) -> Void

    @State private var settings: ModelSettings
    @State private var store = LocalModelStore.shared
    // UI only the simple look's open step, the downloads come after the third
    @State private var page = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple

    init(defaults: UserDefaults, onChange: @escaping (ModelSettings) -> Void) {
        self.defaults = defaults
        self.onChange = onChange
        _settings = State(initialValue: ModelSettings.load(from: defaults))
    }

    private var isSimple: Bool { look == .simple }
    private var model: ReaderSetupViewModel { .live(settings) }
    private var steps: [ReaderStep] { ReaderStep.allCases }

    // pages pushed from the classic list
    private enum Subpage: Hashable { case step(ReaderStep), moreModels, mac }

    var body: some View {
        NavigationStack {
            Group {
                if isSimple { simplePages } else { classicRoot }
            }
            .remedyBackground()
            .navigationTitle(ReaderSetupViewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCapsuleButton(title: model.doneButton) { dismiss() }
            }
            .navigationDestination(for: Subpage.self) { subpage in
                switch subpage {
                case .step(let step): stepPage(step)
                case .moreModels: moreModelsPage
                case .mac: macPage
                }
            }
        }
        .presentationDetents(isSimple ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground { RemedyBackground() }
        .presentationCornerRadius(Radius.large)
    }

    // MARK: - Classic, the three steps then what is on this iPhone and the connections

    private var classicRoot: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                Text(ReaderSetupViewModel.intro)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 4)
                GroupedCard {
                    ForEach(steps) { step in
                        NavigationLink(value: Subpage.step(step)) {
                            let current = model.current(for: step)
                            ItemRow(kind: .custom(symbol: step.symbol, tone: step == .hiding ? .stop : .good),
                                    title: step.title, detail: current?.title ?? "") {
                                HStack(spacing: 8) {
                                    if let place = current?.privacy { PrivacyBadge(place: place) }
                                    Chevron()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                ListHeader(title: "On this iPhone", trailing: LocalModelList.usedText(store))
                LocalModelList(store: store, show: .downloaded)
                GroupedCard {
                    NavigationLink(value: Subpage.moreModels) {
                        ItemRow(kind: .goal(symbol: "arrow.down.circle"), title: "Get more models") { Chevron() }
                    }
                    .buttonStyle(.plain)
                }

                ListHeader(title: "Connections")
                GroupedCard {
                    NavigationLink(value: Subpage.mac) {
                        ItemRow(kind: .custom(symbol: "desktopcomputer", tone: .neutral), title: "My Mac",
                                detail: macLine) { Chevron() }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, Spacing.scrollBottom)
        }
    }

    // the Mac row says if it is the one making the plan
    private var macLine: String {
        settings.plannerChoice.id == .yourMac ? "Making your plan \u{00B7} stays on your network" : "LM Studio, oMLX or Ollama"
    }

    // one step: single choice rows, grouped by where the page goes
    private func stepPage(_ step: ReaderStep) -> some View {
        let cards = model.cards(for: step)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                Text(model.note(for: step))
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 4)
                ForEach(PrivacyGroup.allCases) { group in
                    let inGroup = cards.filter { group.contains($0.privacy) }
                    if !inGroup.isEmpty {
                        ListHeader(title: group.title)
                        GroupedCard {
                            ForEach(inGroup) { card in
                                ReaderChoiceRow(card: card, store: store) { pick(card, in: step) }
                            }
                        }
                    }
                }
                if step == .plan, settings.plannerChoice.id == .yourMac {
                    MacConnectionPanel()
                        .padding(Spacing.insideCard)
                        .cardStyle()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if step == .page {
                    Text("Photo readers are slower, about a minute a page.")
                        .font(.footnote)
                        .foregroundStyle(Color.ink2)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .remedyBackground()
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var moreModelsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                Text(ReaderSetupViewModel.modelsNote)
                    .font(.subheadline)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 4)
                LocalModelList(store: store, show: .available)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, Spacing.scrollBottom)
        }
        .remedyBackground()
        .navigationTitle("Get more models")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var macPage: some View {
        ScrollView {
            MacConnectionPanel()
                .padding(Spacing.insideCard)
                .cardStyle()
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.top, 8)
                .padding(.bottom, Spacing.scrollBottom)
        }
        .remedyBackground()
        .navigationTitle("My Mac")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Simple, one decision per screen

    private var downloadsHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(ReaderSetupViewModel.modelsTitle, systemImage: "arrow.down.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(ReaderSetupViewModel.modelsNote)
                .font(.body)
                .foregroundStyle(Color.ink2)
        }
    }

    private var simplePages: some View {
        VStack(spacing: 0) {
            FitOrScroll {
                VStack(alignment: .leading, spacing: 14) {
                    if steps.indices.contains(page) {
                        let step = steps[page]
                        Text(model.progress(step))
                            .font(.headline)
                            .foregroundStyle(Color.ink2)
                        SegmentBar(total: steps.count, filled: page + 1, tone: .info)
                        Text(step.question)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(model.note(for: step))
                            .font(.title3)
                            .foregroundStyle(Color.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        cards(step)
                    } else {
                        downloadsHeader
                        LocalModelList(store: store, isSimple: true)
                    }
                }
                .id(page)
                .transition(.slideIn(reduceMotion: reduceMotion))
                .padding(.horizontal, Spacing.simpleEdge)
                .padding(.vertical, 8)
            }
            simpleBar
        }
    }

    private var hasDownloads: Bool { LocalModel.allCases.contains(where: \.fitsThisPhone) }
    private var lastPage: Int { hasDownloads ? steps.count : steps.count - 1 }

    private var simpleBar: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button {
                    Motion.perform(reduceMotion) { page -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
            }
            Button {
                if page >= lastPage { dismiss() } else { Motion.perform(reduceMotion) { page += 1 } }
            } label: {
                if page >= lastPage {
                    Label(model.doneButton, systemImage: "checkmark")
                } else {
                    Label(model.nextButton, systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
            }
            .buttonStyle(SimpleButtonStyle())
        }
        .padding(Spacing.simpleEdge)
    }

    private func cards(_ step: ReaderStep) -> some View {
        VStack(spacing: Spacing.betweenCards) {
            ForEach(model.cards(for: step)) { card in
                ReaderChoiceCardView(card: card, isSimple: true, store: store) { pick(card, in: step) }
            }
            // picking your Mac shows where to find it right under the cards
            if step == .plan, settings.plannerChoice.id == .yourMac {
                MacConnectionPanel(isSimple: true)
                    .padding(Spacing.insideCard)
                    .cardStyle()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // saved the moment it is picked so there is nothing to forget
    private func pick(_ card: ReaderCard, in step: ReaderStep) {
        var changed = model
        guard changed.pick(card.id, in: step) else { return }
        Motion.perform(reduceMotion) { settings = changed.settings }
        settings.save(to: defaults)
        onChange(settings)
    }
}

// the three places a page can go, shown as the headers of a step's choices
enum PrivacyGroup: Int, CaseIterable, Identifiable {
    case phone, mac, off
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .phone: return "On this iPhone"
        case .mac: return "My Mac"
        case .off: return "Off this phone"
        }
    }

    func contains(_ place: PrivacyPlace) -> Bool {
        switch self {
        case .phone: return place == .thisPhone
        case .mac: return place == .homeNetwork
        case .off: return place == .appleCloud || place == .online
        }
    }
}
