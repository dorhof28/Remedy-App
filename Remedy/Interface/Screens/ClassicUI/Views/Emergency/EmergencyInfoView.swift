//
//  EmergencyInfoView.swift
//  Remedy
//
//  classic emergency info (screen 57): a short note for Medical ID, copy it, and a card to keep
//

import SwiftUI
import SwiftData

// classic emergency info: the medical id text and wallet card
struct EmergencyInfoView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the copied flag and the made card
    @State private var didCopy = false
    @State private var cardURL: URL?

    var body: some View {
        let viewModel = EmergencyInfoViewModel(plan: plans.first, now: AppClock.now())
        List {
            if viewModel.hasPlan {
                Section {
                    ActionCard(style: .card, eyebrow: EmergencyInfoViewModel.eyebrow, eyebrowSymbol: "staroflife",
                               text: viewModel.paragraph)
                        .textSelection(.enabled)
                        .plainListRow()
                } footer: {
                    Text(EmergencyInfoViewModel.footer).font(.footnote).foregroundStyle(Color.ink2)
                }
                Section {
                    VStack(spacing: 10) {
                        PrimaryButton(title: didCopy ? EmergencyInfoViewModel.copiedButton : EmergencyInfoViewModel.copyButton,
                                      symbol: didCopy ? "checkmark" : "doc.on.doc") {
                            UIPasteboard.general.string = viewModel.paragraph
                            didCopy = true
                        }
                        .sensoryFeedback(.success, trigger: didCopy) { _, copied in copied }
                        if let cardURL {
                            ShareLink(item: cardURL) {
                                Label(EmergencyInfoViewModel.walletButton, systemImage: "wallet.pass")
                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: Spacing.buttonHeight)
                            }
                            .buttonStyle(CapsuleFillStyle(fill: .surface2, text: .ink))
                        } else {
                            SecondaryButton(title: EmergencyInfoViewModel.walletButton, symbol: "wallet.pass") {
                                cardURL = viewModel.makeCardPDF()
                            }
                        }
                    }
                    .plainListRow()
                }
            } else {
                Section { Text(viewModel.noPlanText).font(.body).foregroundStyle(Color.ink2) }
            }
        }
        .remedyList()
        .navigationTitle(EmergencyInfoViewModel.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { EmergencyInfoView() }
}
