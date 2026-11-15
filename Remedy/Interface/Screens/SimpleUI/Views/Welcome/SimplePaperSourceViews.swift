//
//  SimplePaperSourceViews.swift
//  Remedy
//
//  simple look of confirming who gave the paper and the printed date
//  one question on each screen, the doctor is read from the paper
//

import SwiftUI

// who gave it, then the printed date
struct SimplePaperDetailsView: View {
    @Bindable var viewModel: ScanFlowViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(viewModel.detailsProgress)
                    .font(.headline)
                    .foregroundStyle(Color.ink2)
                Text(viewModel.detailsQuestion)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                switch viewModel.detailsStep {
                case .kind: PaperKindQuestion(viewModel: viewModel, isSimple: true)
                case .who: who
                case .date: date
                }
            }
            .padding(Spacing.simpleEdge)
        }
        .id(viewModel.detailsStep)
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .remedyBackground()
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    viewModel.goBack()
                } label: {
                    Label(viewModel.backButton, systemImage: "chevron.left")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
                Button {
                    Task { await viewModel.nextDetail() }
                } label: {
                    Label(viewModel.nextButton, systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(SimpleButtonStyle())
            }
            .padding(Spacing.simpleEdge)
            .onboardingBar()
        }
    }

    private var who: some View {
        VStack(alignment: .leading, spacing: 12) {
            FoundTag(isFound: viewModel.sourceWasFound, viewModel: viewModel)
            if let hospital = viewModel.foundHospital {
                Label("\(viewModel.hospitalFoundTitle): \(hospital)", systemImage: "building.2.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Tone.good.color)
            }
            if let doctor = viewModel.foundDoctor {
                Label("\(viewModel.doctorFoundTitle): \(doctor)", systemImage: "stethoscope")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Tone.good.color)
            }
            OptionCards(items: viewModel.sourceItems, isSimple: true) { viewModel.pickSource($0) }
        }
    }

    private var date: some View {
        VStack(alignment: .leading, spacing: 12) {
            FoundTag(isFound: viewModel.dateWasFound, viewModel: viewModel)
            if viewModel.hasPrintedDate {
                DatePicker(viewModel.printedDateTitle, selection: $viewModel.printedDate,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(8)
                    .cardStyle()
            }
            DetailChoiceRow(title: viewModel.noDateButton, symbol: "calendar.badge.minus",
                            isChosen: !viewModel.hasPrintedDate, isSimple: true) {
                Motion.run { viewModel.hasPrintedDate.toggle() }
            }
            AIChoiceView(onChange: { _ in viewModel.reloadAIChoice() }, showsChangeButton: false,
                         reloadToken: viewModel.aiChoiceVersion)
                .padding(.top, 8)
            SimpleReaderRow { viewModel.reloadAIChoice() }
        }
    }
}
