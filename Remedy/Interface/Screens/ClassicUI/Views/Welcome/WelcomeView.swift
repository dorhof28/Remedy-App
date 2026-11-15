//
//  WelcomeView.swift
//  Remedy
//
//  classic look of the first screen and the page where the papers come from
//

import SwiftUI

// the first screen: get started, demo mode or restore
struct WelcomeView: View {
    @Bindable var viewModel: ScanFlowViewModel

    @Environment(\.dynamicTypeSize) private var typeSize
    // UI only is the restore sheet or demo mode open
    @State private var isRestoring = false
    @State private var isShowingDemo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    // the app icon, decoration only
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .padding(.bottom, 16)
                        .accessibilityHidden(true)
                    Text(viewModel.appName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(viewModel.welcomeDetail)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 24)

                VStack(spacing: 0) {
                    ForEach(viewModel.features) { feature in
                        if feature.id != viewModel.features.first?.id { Divider().padding(.leading, 60) }
                        ListRow(symbol: feature.symbol, title: feature.title, subtitle: feature.detail)
                            .padding(.horizontal, Spacing.insideCard)
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                    }
                }
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))

                DisclaimerBox(text: viewModel.disclaimer)

                if typeSize.isAccessibilitySize { bar }
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.screenBackground)
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize { bar }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $viewModel.showsSources) { PaperSourceSheet(viewModel: viewModel) }
        .sheet(isPresented: $isRestoring) {
            RestoreBackupView(viewModel: SettingsViewModel(plan: nil, now: AppClock.now()))
        }
        // with no plan yet there is no Settings, so demo mode opens from here too
        .sheet(isPresented: $isShowingDemo) {
            DemoModeView()
        }
        .paperIntake(viewModel, request: $viewModel.intakeRequest)
        .task {
            switch await viewModel.openDemoScreen() {
            case "restore": isRestoring = true
            case "demo": isShowingDemo = true
            default: break
            }
        }
    }

    // one primary button, then demo and restore side by side
    private var bar: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: viewModel.welcomeButton) { viewModel.begin() }
                .accessibilityIdentifier("welcome-add")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { secondary }
                VStack(spacing: 12) { secondary }
            }
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var secondary: some View {
        // loading a case turns demo mode on, just looking does not
        SecondaryButton(title: viewModel.demoButton) { isShowingDemo = true }
            .accessibilityIdentifier("welcome-demo")
        SecondaryButton(title: viewModel.restoreButton) { isRestoring = true }
    }
}

// MARK: - Where are the papers

// first pick, where the papers come from, one tap goes on
struct AddPapersView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        FitOrScroll {
            VStack(spacing: Spacing.betweenCards) {
                if let error = viewModel.errorText {
                    ToneBox(eyebrow: "Try again", title: error, tone: .caution)
                    if viewModel.showsTryOnPhone {
                        Button {
                            Task { await viewModel.tryOnPhone() }
                        } label: {
                            Text(viewModel.tryOnPhoneButton)
                        }
                        .buttonStyle(RemedyButtonStyle(kind: .secondary))
                    }
                }
                PaperSourcePicker(viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
        }
        .navigationTitle(viewModel.addPapersTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.isAddingPapers || viewModel.asksPaperKind {
                ToolbarItem(placement: .navigation) {
                    Button(viewModel.backButton) { viewModel.goBack() }
                }
            }
        }
        .paperIntake(viewModel, request: $viewModel.intakeRequest)
    }
}
