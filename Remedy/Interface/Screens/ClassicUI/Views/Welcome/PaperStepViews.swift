//
//  PaperStepViews.swift
//  Remedy
//
//  the pages before reading, the reading screen, and the screens for a hard page or no cloud
//

import SwiftUI

// MARK: - Pages scanned

// check the pages before anything is read
struct PagesScannedView: View {
    @Bindable var viewModel: ScanFlowViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    private var continueButton: some View {
        PrimaryButton(title: "Continue") { Task { await viewModel.readPages() } }
    }

    var body: some View {
        List {
            // the hint is the footer so the rounded row never clips it
            Section {
                PageThumbnails(images: viewModel.pendingImages)
                    .plainListRow()
            } footer: {
                Text(viewModel.pagesHint)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                    .textCase(nil)
                    .padding(.top, 8)
            }
            Section {
                Button { viewModel.scanMore() } label: {
                    ListRow(symbol: "camera", title: viewModel.scanMoreButton, showsChevron: true)
                }
                Button { viewModel.addElsewhere() } label: {
                    ListRow(symbol: "doc.text", title: viewModel.addElsewhereButton,
                            subtitle: viewModel.addElsewhereDetail, showsChevron: true)
                }
            }
            .buttonStyle(.plain)
            // at accessibility sizes the button ends the page instead of covering it
            if typeSize.isAccessibilitySize {
                Section { continueButton.plainListRow() }
            }
        }
        .remedyList()
        .navigationTitle(viewModel.pagesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(viewModel.cancelButton) {
                    viewModel.pendingImages = []
                    viewModel.cancelReading()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize {
                continueButton
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $viewModel.showsSources) { PaperSourceSheet(viewModel: viewModel) }
        .paperIntake(viewModel, request: $viewModel.intakeRequest)
    }
}

// MARK: - Reading

// says what it is doing, page by page, nothing has been sent yet
struct ReadingProgressView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(viewModel.readingHeadline)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Text(viewModel.readingDetail)
                .font(.body)
                .foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let progress = viewModel.readingProgress {
                ProgressView(value: progress)
                    .tint(Color.remedyTeal)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.screenEdge + 8)
        .frame(maxWidth: .infinity)
        .background(Color.screenBackground)
        .safeAreaInset(edge: .bottom) {
            SecondaryButton(title: viewModel.cancelButton) { viewModel.cancelReading() }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 8)
        }
        .navigationTitle(viewModel.readingNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Problems

// a page that couldn't be read, or the cloud that couldn't be reached
struct PaperProblemView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        Group {
            if viewModel.hardPage != nil {
                HeroScreen(symbol: "exclamationmark.triangle", tone: .caution,
                           title: viewModel.hardPageTitle, text: viewModel.hardPageDetail) {
                    PrimaryButton(title: viewModel.scanAgainButton, symbol: "camera") { viewModel.scanHardPageAgain() }
                    SecondaryButton(title: viewModel.skipPageButton) { Task { await viewModel.skipHardPage() } }
                }
            } else if viewModel.showsTryOnPhone {
                HeroScreen(symbol: "exclamationmark.triangle", tone: .caution,
                           title: viewModel.cloudTitle, text: viewModel.cloudDetail) {
                    PrimaryButton(title: viewModel.tryAgainButton) { Task { await viewModel.tryCloudAgain() } }
                    SecondaryButton(title: viewModel.keepOnPhoneButton) { Task { await viewModel.tryOnPhone() } }
                }
            } else {
                HeroScreen(symbol: "exclamationmark.triangle", tone: .caution,
                           title: viewModel.errorText ?? "", text: "") {
                    PrimaryButton(title: viewModel.tryAgainButton) {
                        viewModel.errorText = nil
                        viewModel.begin()
                    }
                }
            }
        }
        .navigationTitle(viewModel.readingNavTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $viewModel.showsSources) { PaperSourceSheet(viewModel: viewModel) }
        .paperIntake(viewModel, request: $viewModel.intakeRequest)
    }
}
