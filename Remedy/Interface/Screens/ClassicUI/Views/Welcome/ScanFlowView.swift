//
//  ScanFlowView.swift
//  Remedy
//
//  welcome scan and confirm flow
//

import SwiftUI
import SwiftData

// shows the scan flow's current step
struct ScanFlowView: View {

    @State private var viewModel: ScanFlowViewModel
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLook.storageKey) private var savedLook: AppLook = .simple
    // the first setup is always classic, adding papers later keeps the saved look
    private var look: AppLook { viewModel.isAddingPapers ? savedLook : .classic }

    init(isAddingPapers: Bool = false, planHasSurgeryDate: Bool = false) {
        _viewModel = State(initialValue: ScanFlowViewModel(isAddingPapers: isAddingPapers,
                                                           planHasSurgeryDate: planHasSurgeryDate))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                switch viewModel.step {
                case .welcome:
                    WelcomeView(viewModel: viewModel)
                case .addPapers:
                    if viewModel.errorText != nil {
                        PaperProblemView(viewModel: viewModel)
                    } else if look == .simple {
                        SimpleAddPapersView(viewModel: viewModel)
                    } else {
                        AddPapersView(viewModel: viewModel)
                    }
                case .pages:
                    PagesScannedView(viewModel: viewModel)
                case .importPick:
                    ImportPickView(viewModel: viewModel)
                case .paperDetails:
                    if look == .simple { SimplePaperDetailsView(viewModel: viewModel) } else { PaperDetailsView(viewModel: viewModel) }
                case .reading: ReadingProgressView(viewModel: viewModel)
                case .checkHidden:
                    // the consent opens over the reading screen, nothing is sent until Send
                    ReadingProgressView(viewModel: viewModel)
                        .sheet(isPresented: .constant(true)) { CheckHiddenView(viewModel: viewModel) }
                case .confirm: ConfirmView(viewModel: viewModel)
                case .finish: FinishView(viewModel: viewModel) { dismiss() }
                case .whatChanged:
                    if let changes = viewModel.whatChanged {
                        let footer = WhatChangedViewModel.footer(plan: plans.first)
                        if look == .simple { SimpleWhatChangedView(viewModel: changes, footer: footer) } else { WhatChangedView(viewModel: changes, footer: footer) }
                    }
                case .setup:
                    SetupStepView(viewModel: viewModel)
                }
            }
            // reading and checking fade, so the page that was just read never jumps
            .transition(viewModel.step == .reading || viewModel.step == .checkHidden
                        ? .opacity : .slideIn(reduceMotion: reduceMotion))
            .remedyBackground()
            .sheet(isPresented: $viewModel.showsSendSheet) { WhatGetsSentSheet(viewModel: viewModel) }
            .sheet(isPresented: $viewModel.showsAIChoice) {
                AIChoiceSheet(defaults: .standard) { _ in
                    viewModel.reloadAIChoice()
                }
            }
            .toolbar {
                // how papers are read, up top so the screen keeps its room, the first screen has the settings gear instead
                if [.addPapers, .paperDetails].contains(viewModel.step), viewModel.errorText == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showsAIChoice = true
                        } label: {
                            Label("Change how papers are read", systemImage: "slider.horizontal.3")
                        }
                        .labelStyle(.iconOnly)
                        .frame(minWidth: Spacing.minTarget, minHeight: Spacing.minTarget)
                    }
                }
                if viewModel.isAddingPapers {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(viewModel.cancelButton) { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Finish (summary + surgery date)

// all done screen
struct FinishView: View {
    @Bindable var viewModel: ScanFlowViewModel
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @AppStorage(AppLook.storageKey) private var savedLook: AppLook = .simple
    // the first setup is always classic, adding papers later keeps the saved look
    private var look: AppLook { viewModel.isAddingPapers ? savedLook : .classic }

    // the are you sure question when no date was picked
    @State private var isCheckingDate = false

    private var isSimple: Bool { look == .simple }
    @Environment(\.dynamicTypeSize) private var typeSize

    private var doneButton: some View {
        PrimaryButton(title: viewModel.doneButton, action: start)
            .sensoryFeedback(.success, trigger: viewModel.step)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HeroMessage(symbol: "checkmark.circle", tone: .good, title: viewModel.finishTitle, text: viewModel.finishDetail)
                    .padding(.top, 40)
                if !viewModel.finishRows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.finishRows) { row in
                            if row.id != viewModel.finishRows.first?.id { Divider().padding(.leading, 60) }
                            ListRow(symbol: row.symbol, tone: row.tone, title: row.title, subtitle: row.detail)
                                .padding(.horizontal, Spacing.insideCard).padding(.vertical, 10)
                                .accessibilityElement(children: .combine)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
                }
                if viewModel.needsSurgeryDate {
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker(viewModel.surgeryDateTitle, selection: $viewModel.surgeryDate, displayedComponents: .date)
                            .font(.headline)
                            .frame(minHeight: Spacing.minTarget)
                            .onChange(of: viewModel.surgeryDate) { viewModel.hasPickedDate = true }
                        Text(viewModel.surgeryDateDetail)
                            .font(.footnote)
                            .foregroundStyle(Color.ink2)
                    }
                    .padding(Spacing.insideCard)
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
                }
                if typeSize.isAccessibilitySize { doneButton }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 24)
        }
        .background(Color.screenBackground)
        // at accessibility sizes the button ends the page instead of covering it
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                doneButton
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.bottom, 8)
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert(viewModel.checkDateTitle, isPresented: $isCheckingDate) {
            Button(viewModel.checkDateYes) { proceed() }
            Button(viewModel.checkDateNo, role: .cancel) {}
        } message: {
            Text(viewModel.surgeryDateDetail)
        }
    }

    // a guessed surgery date is confirmed before the plan starts
    private func start() {
        if viewModel.asksToCheckDate {
            isCheckingDate = true
        } else {
            proceed()
        }
    }

    // setup questions now wait for the moment each is needed, so done saves straight away
    private func proceed() {
        // a sheet closes; on first run the tabs appear by themselves
        if viewModel.save(in: context) { onDone() }
    }

    @ViewBuilder
    private var startButton: some View {
        if isSimple {
            Button(action: start) {
                Label(viewModel.startButton, systemImage: "checkmark")
            }
            .buttonStyle(SimpleButtonStyle())
            .sensoryFeedback(.success, trigger: viewModel.step)
        } else {
            Button(action: start) {
                Text(viewModel.startButton)
            }
            .buttonStyle(RemedyButtonStyle())
            .sensoryFeedback(.success, trigger: viewModel.step)
        }
    }
}

#Preview("First run") {
    ScanFlowView()
        .modelContainer(for: RemedySchema.models, inMemory: true)
}

// MARK: - About this paper (confirm what was found)

// who gave it, the doctor, where it is from, the printed date and what it covers
// the doctor is read from the paper, so there is nothing to type
struct PaperDetailsView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        List {
            Section {
                ForEach(NewerPaperRule.Giver.allCases, id: \.self) { giver in
                    RadioRow(title: giver.title, isOn: viewModel.shownGiver == giver) {
                        Motion.run { viewModel.pickGiver(giver) }
                    }
                }
            } header: {
                ListSectionHeader(title: viewModel.whoTitle)
            }

            Section {
                NavigationLink {
                    TextFieldPage(title: viewModel.doctorTitle, text: $viewModel.doctorName, prompt: "Dr. Ama Okafor")
                } label: {
                    ListRow(symbol: "person.crop.circle", title: viewModel.doctorTitle,
                            value: viewModel.foundDoctor ?? viewModel.notFoundText)
                }
                NavigationLink {
                    TextFieldPage(title: viewModel.hospitalFoundTitle, text: $viewModel.hospitalText, prompt: "Lakeside Orthopedics")
                } label: {
                    ListRow(symbol: "building.2", title: viewModel.hospitalFoundTitle,
                            value: viewModel.foundHospital ?? viewModel.notFoundText)
                }
                if viewModel.hasPrintedDate {
                    NavigationLink {
                        PrintedDatePage(viewModel: viewModel)
                    } label: {
                        ListRow(symbol: "calendar", title: viewModel.printedOnTitle, value: viewModel.printedDateText)
                    }
                }
                // on means no date, Remedy never guesses one
                Toggle(isOn: Binding(get: { !viewModel.hasPrintedDate },
                                     set: { off in Motion.run { viewModel.hasPrintedDate = !off } })) {
                    ListRow(symbol: "calendar", title: viewModel.noDateTitle)
                }
                .tint(Color.accentFill)
            } header: {
                ListSectionHeader(title: viewModel.fromPageTitle)
            }

            Section {
                Picker(viewModel.coversTitle, selection: Binding(get: { viewModel.paper },
                                                                 set: { viewModel.pickPaper($0.rawValue) })) {
                    Text(viewModel.beforeSurgeryTitle).tag(PaperKind.beforeSurgery)
                    Text(viewModel.afterSurgeryTitle).tag(PaperKind.afterSurgery)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .plainListRow()
            } header: {
                ListSectionHeader(title: viewModel.coversTitle)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.asksKind {
                        Label(viewModel.kindNote, systemImage: "text.magnifyingglass")
                            .foregroundStyle(Tone.caution.color)
                    }
                    Text(viewModel.readingWithFooter)
                }
                .font(.footnote)
                .foregroundStyle(Color.ink2)
                .padding(.top, 8)
            }
        }
        .remedyList()
        .navigationTitle(viewModel.detailsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(viewModel.backButton, systemImage: "chevron.left") { viewModel.goBack() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue") { Task { await viewModel.confirmPaperDetails() } }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 8)
        }
    }
}

// the printed date, a calendar so a typed date is never guessed
struct PrintedDatePage: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        List {
            DatePicker(viewModel.printedOnTitle, selection: $viewModel.printedDate, in: ...AppClock.now(),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Color.accentFill)
        }
        .remedyList()
        .navigationTitle(viewModel.printedOnTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// says if a value came from the paper or was left blank, used by both looks
struct FoundTag: View {
    let isFound: Bool
    let viewModel: ScanFlowViewModel

    var body: some View {
        Label(isFound ? viewModel.foundText : viewModel.blankText,
              systemImage: isFound ? "doc.text.magnifyingglass" : "questionmark.circle")
            .font(.callout.weight(.semibold))
            .foregroundStyle(isFound ? Tone.good.color : Color.secondary)
    }
}
