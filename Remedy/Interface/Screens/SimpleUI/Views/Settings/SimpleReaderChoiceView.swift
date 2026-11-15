//
//  SimpleReaderChoiceView.swift
//  Remedy
//
//  simple look of picking who makes the plan, one decision with big cards
//  each card says where the page goes and which one Remedy recommends
//

import SwiftUI

// simple pick who reads the papers
struct SimpleReaderChoiceView: View {

    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue
    @AppStorage(ModelSettings.redactKey) private var hides = true

    // UI only asking before hiding is turned off, and the full three step sheet
    @State private var isConfirmingHideOff = false
    @State private var isShowingAllSteps = false
    @State private var store = LocalModelStore.shared
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let viewModel = SettingsViewModel(plan: nil, now: AppClock.now())
        SimpleScreen(title: ReaderStep.plan.question) {
            if typeSize < .xLarge {
                Text(viewModel.readerIntro)
                    .font(.title3)
            }

            ForEach(cards(viewModel)) { card in
                ReaderChoiceCardView(card: card, isSimple: true, store: store) {
                    guard let choice = ModelChoice.all.first(where: { $0.id.rawValue == card.id }) else { return }
                    viewModel.choosePlanner(choice)
                    plannerID = choice.id.rawValue
                }
            }

            if plannerID == ModelChoice.ID.yourMac.rawValue {
                MacConnectionPanel(isSimple: true)
                    .padding(18)
                    .cardStyle()
            }

            Toggle(isOn: Binding(get: { hides }, set: { isOn in
                if !isOn && viewModel.confirmsTurningOffHiding {
                    isConfirmingHideOff = true
                } else {
                    hides = isOn
                }
            })) {
                Label(viewModel.hideToggle, systemImage: "eye.slash.fill")
                    .font(.title3.bold())
            }
            .tint(Color.accentFill)
            .padding(18)
            .frame(minHeight: 72)
            .settingsCardStyle()

            Button {
                isShowingAllSteps = true
            } label: {
                Label(ReaderSetupViewModel.title, systemImage: "slider.horizontal.3")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
        }
        .alert(viewModel.hideOffTitle, isPresented: $isConfirmingHideOff) {
            Button(viewModel.hideOffButton, role: .destructive) { hides = false }
            Button(viewModel.hideKeepButton, role: .cancel) {}
        } message: {
            Text(viewModel.hideOffMessage)
        }
        .sheet(isPresented: $isShowingAllSteps) {
            AIChoiceSheet(defaults: .standard) { changed in plannerID = changed.plannerChoice.id.rawValue }
        }
    }

    // every reader as a big card, the plain subtitle kept so a missing key still shows
    private func cards(_ viewModel: SettingsViewModel) -> [ReaderCard] {
        ModelChoice.all.map { choice in
            let isChosen = plannerID == choice.id.rawValue
            let subtitle = viewModel.simpleReaderSubtitle(choice, isChosen: isChosen)
            return ReaderCard(id: choice.id.rawValue, symbol: viewModel.readerSymbol(choice), title: choice.displayName,
                              detail: subtitle.isEmpty ? (choice.hint ?? choice.leavesPhoneLine(sendsPhoto: false)) : subtitle,
                              privacy: .of(choice), isRecommended: choice.id == .onPhone,
                              isSelected: isChosen, isReady: viewModel.isSelectable(choice))
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleReaderChoiceView() }
}
