//
//  SimpleWelcomeViews.swift
//  Remedy
//
//  simple look of the page where the papers come from
//  big buttons and one thing on each screen
//

import SwiftUI

// where are your papers
struct SimpleAddPapersView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        SimpleFit {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.isAddingPapers || viewModel.asksPaperKind {
                    SimpleBackPill(title: viewModel.backButton) { viewModel.goBack() }
                }
                if !viewModel.asksPaperKind {
                    Text(viewModel.chooseSourceTitle)
                        .font(.largeTitle.bold())
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if let error = viewModel.errorText {
                    ToneBox(eyebrow: "Try again", title: error, tone: .caution)
                    if viewModel.showsTryOnPhone {
                        Button {
                            Task { await viewModel.tryOnPhone() }
                        } label: {
                            Label(viewModel.tryOnPhoneButton, systemImage: "iphone")
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                    }
                }
                PaperSourcePicker(viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.screenEdge)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .remedyBackground()
        .navigationBarBackButtonHidden()
        .toolbar(viewModel.isAddingPapers ? .automatic : .hidden, for: .navigationBar)
        .paperIntake(viewModel, request: $viewModel.intakeRequest)
    }
}
