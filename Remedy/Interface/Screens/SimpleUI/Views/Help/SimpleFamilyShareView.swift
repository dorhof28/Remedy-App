//
//  SimpleFamilyShareView.swift
//  Remedy
//
//  simple share with family
//

import SwiftUI
import SwiftData

struct SimpleFamilyShareView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the finished PDF
    @State private var pdfURL: URL?
    @State private var didFail = false

    var body: some View {
        let viewModel = FamilyShareViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.title) {
            Text(viewModel.familyIntro)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .minimumScaleFactor(0.8)

            FamilySheetPreview(sheet: viewModel.sheet)
                .frame(maxHeight: 360)

            Spacer(minLength: 0)

            FamilyShareButton(url: pdfURL, didFail: didFail, viewModel: viewModel)
                .font(.title3.bold())
        }
        .task {
            pdfURL = viewModel.makePDF()
            didFail = pdfURL == nil
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleFamilyShareView() }
}
