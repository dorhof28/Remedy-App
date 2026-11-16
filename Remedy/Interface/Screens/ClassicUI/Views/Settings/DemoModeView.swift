//
//  DemoModeView.swift
//  Remedy
//
//  classic look of Demo mode: the sample patients, the pretend date,
//  the connection check in test builds and the way back
//

import SwiftUI
import SwiftData

extension Notification.Name {
    // the app redraws from the top so every screen reads the new fake today
    static let demoClockChanged = Notification.Name("demoClockChanged")
}

// demo mode: fake patients and the fake clock
struct DemoModeView: View {

    @Environment(\.dismiss) private var dismiss
    // UI only where the clock started
    @State private var startShift = LaunchOptions.demoDayShift

    var body: some View {
        NavigationStack {
            DemoHomePage { dismiss() }
        }
        .onDisappear {
            if LaunchOptions.demoDayShift != startShift { NotificationCenter.default.post(name: .demoClockChanged, object: nil) }
        }
    }
}

// screen 74: the sample patients, the pretend date, then testing
private struct DemoHomePage: View {

    let close: () -> Void
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @AppStorage(LaunchOptions.demoLoadedKey) private var loaded = ""
    @AppStorage(LaunchOptions.demoModeKey) private var isOn = false
    // UI only loading a patient or leaving
    @State private var loader = DemoLoader()

    @State private var isTestBuild = false

    var body: some View {
        let viewModel = DemoModeViewModel()
        List {
            Section {
                ForEach(DemoModeViewModel.featured) { scenario in
                    DemoPlanCard(scenario: scenario, status: loader.status(scenario, loaded: loaded)) {
                        loader.tap(scenario, plans: plans, in: context)
                    }
                }
                NavigationLink { DemoMorePatientsPage() } label: {
                    ListRow(symbol: "list.bullet", title: viewModel.otherPlansTitle)
                }
                NavigationLink { DemoSamplePapersPage() } label: {
                    ListRow(symbol: "doc.text.magnifyingglass", title: viewModel.samplePapersTitle, subtitle: viewModel.samplePapersDetail)
                }
                .accessibilityIdentifier("demo-sample-papers")
            } header: {
                ListSectionHeader(title: viewModel.patientsTitle)
            }
            Section {
                DemoDateRows()
            } header: {
                ListSectionHeader(title: viewModel.clockTitle)
            }
            // testflight and debug builds only, checks MyChart and Health
            if isTestBuild {
                Section {
                    NavigationLink { ConnectionCheckView() } label: {
                        ListRow(symbol: "antenna.radiowaves.left.and.right", title: viewModel.connectionTitle,
                                subtitle: viewModel.connectionDetail)
                    }
                } header: {
                    ListSectionHeader(title: viewModel.testingTitle)
                }
            }
        }
        .remedyList()
        .task { isTestBuild = await BuildKind.isTest() }
        .navigationTitle(viewModel.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOn || !loaded.isEmpty {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.leaveButton) { loader.isConfirmingExit = true }
                        .disabled(loader.isWorking)
                        .accessibilityIdentifier("demo-exit")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.doneButton, action: close)
            }
        }
        .overlay { if loader.isExiting { ProgressView().controlSize(.large) } }
        .demoLoaderDialogs(loader, hasPlan: !plans.isEmpty, context: context)
    }
}

// the pretend date, a jump to the surgery day and the way back to the real date
private struct DemoDateRows: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @AppStorage(LaunchOptions.demoShiftKey) private var shift = 0

    var body: some View {
        let viewModel = DemoModeViewModel()
        HStack(spacing: 14) {
            RowIcon(symbol: "calendar")
            Text(viewModel.dateRowTitle)
                .font(.body)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 8)
            DatePicker(viewModel.pickDateTitle,
                       selection: Binding(get: { AppClock.now() }, set: { viewModel.setToday($0); shift = viewModel.shift }),
                       displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .fixedSize()
        }
        .frame(minHeight: Spacing.minTarget)
        .accessibilityElement(children: .combine)
        if plans.first?.surgeryDate != nil {
            Button {
                viewModel.jumpToSurgery(of: plans.first)
                shift = viewModel.shift
            } label: {
                ListRow(symbol: "bed.double", title: viewModel.toSurgeryTitle)
            }
            .buttonStyle(.plain)
        }
        if shift != 0 {
            Button {
                viewModel.resetToday()
                shift = 0
            } label: {
                ListRow(symbol: "arrow.uturn.backward", title: viewModel.resetClockTitle,
                        subtitle: DemoModeViewModel.shiftWords(shift))
            }
            .buttonStyle(.plain)
        }
    }
}

// the other sample patients by group, one tap opens one
private struct DemoMorePatientsPage: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @AppStorage(LaunchOptions.demoLoadedKey) private var loaded = ""
    // UI only loading a patient
    @State private var loader = DemoLoader()

    var body: some View {
        let viewModel = DemoModeViewModel()
        List {
            ForEach(DemoModeViewModel.otherGroups) { group in
                Section {
                    ForEach(DemoScenario.scenarios(in: group)) { scenario in
                        DemoPlanCard(scenario: scenario, status: loader.status(scenario, loaded: loaded)) {
                            loader.tap(scenario, plans: plans, in: context)
                        }
                    }
                } header: {
                    ListSectionHeader(title: group.title)
                }
            }
        }
        .remedyList()
        .navigationTitle(viewModel.otherPlansTitle)
        .navigationBarTitleDisplayMode(.inline)
        .demoLoaderDialogs(loader, hasPlan: !plans.isEmpty, context: context)
    }
}

// the HSS sample papers: open one, flip through it, share it to Files to add it like a real paper
private struct DemoSamplePapersPage: View {

    var body: some View {
        let viewModel = DemoModeViewModel()
        List {
            Section {
                ForEach(DemoPapers.all) { item in
                    NavigationLink { DemoPaperPage(item: item) } label: {
                        ListRow(symbol: "doc.text", title: item.title, subtitle: item.detail)
                    }
                }
            } footer: {
                Text(viewModel.samplePapersIntro)
            }
        }
        .remedyList()
        .navigationTitle(viewModel.samplePapersTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// one sample paper full screen with a share button
private struct DemoPaperPage: View {

    let item: DemoPapers.Item
    // UI only the page on screen
    @State private var page = 1

    var body: some View {
        Group {
            if let url = item.url {
                PDFPreview(url: url, page: $page)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            ShareLink(item: url, subject: Text(item.title)) {
                                Label(DemoModeViewModel().shareTitle, systemImage: "square.and.arrow.up")
                            }
                        }
                    }
            } else {
                ContentUnavailableView(item.title, systemImage: "doc.questionmark")
            }
        }
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
