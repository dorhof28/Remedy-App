//
//  SimpleHelpView.swift
//  Remedy
//
//  simple help (83): 911 first, then up to two people, then when to call
//

import SwiftUI
import SwiftData

// simple help
struct SimpleHelpView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only is the contacts editor open
    @State private var isEditingContacts = false

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        let screen = SimpleHelpScreen(base: viewModel)
        SimpleScreen(title: screen.title) {
            if let url = viewModel.emergencyURL {
                Link(destination: url) {
                    Label(screen.call911, systemImage: "phone.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .danger))
                .accessibilityHint(viewModel.emergencyDetail)
            }
            Text(screen.emergencyText)
                .font(.title3)
                .foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(screen.calls, id: \.row.id) { call in
                if let url = call.row.phoneURL {
                    Link(destination: url) {
                        Label(call.title, systemImage: "phone.fill")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .gray))
                    .accessibilityHint(call.row.phoneText)
                }
            }
            if !viewModel.showsContacts {
                Text(viewModel.noContactsText)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            }
            NavigationLink { SimpleWhenToCallPage() } label: {
                Text(screen.whenTitle)
            }
            .buttonStyle(SimpleButtonStyle(kind: .gray))
            NavigationLink { SimpleFamilyShareView() } label: {
                Label("Share With Family", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SimpleButtonStyle(kind: .gray))
            Button { isEditingContacts = true } label: {
                Label(screen.editContactsTitle, systemImage: "person.crop.circle")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain))
        }
        .sheet(isPresented: $isEditingContacts) { HelpContactsSheet() }
    }
}

// when to call (112): one card per warning sign with the right call, then the emergency info
struct SimpleWhenToCallPage: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        let screen = SimpleHelpScreen(base: viewModel)
        SimpleScreen(title: screen.whenPageTitle, readAloud: viewModel.spokenWarnings) {
            ForEach(screen.signCards) { card in
                VStack(alignment: .leading, spacing: 14) {
                    Text(card.text)
                        .font(.title3.bold())
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let url = card.url {
                        Link(destination: url) {
                            Label(card.callTitle, systemImage: "phone.fill")
                        }
                        .buttonStyle(SimpleButtonStyle(kind: card.isEmergency ? .danger : .gray))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .toneCardStyle(card.tone)
            }
            SimpleEmergencyCard()
        }
    }
}

// MARK: - One big "tap to call" button

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleHelpView() }
}

// MARK: - Emergency info on the help page

// what a helper needs: the facts and the wallet card
struct SimpleEmergencyCard: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    var body: some View {
        let viewModel = EmergencyInfoViewModel(plan: plans.first, now: AppClock.now())
        if viewModel.hasPlan {
            SimpleSectionTitle(title: viewModel.title, tone: .stop, symbol: "cross.case")
            VStack(alignment: .leading, spacing: 14) {
                ForEach(viewModel.facts) { fact in
                    HStack(alignment: .top, spacing: 14) {
                        ItemIconTile(kind: .custom(symbol: fact.symbol, tone: .info), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.label)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.ink2)
                            Text(fact.value)
                                .font(.title3.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()

            WalletCardButton(viewModel: viewModel, large: true)
        }
    }
}
