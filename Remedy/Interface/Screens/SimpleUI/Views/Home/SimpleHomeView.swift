//
//  SimpleHomeView.swift
//  Remedy
//
//  simple home screen and its routes
//

import SwiftUI
import SwiftData

// where the big buttons go
enum SimpleRoute: Hashable {
    case medicines
    case medicineGroup(String)
    case plan
    case planGroup(String)
    case ask
    case help
    case warningSigns
    case settings
    case shareWithFamily
}

// navigation for the simple look
struct SimpleRootView: View {
    var body: some View {
        NavigationStack {
            SimpleHomeView()
                .navigationDestination(for: SimpleRoute.self) { route in
                    switch route {
                    case .medicines: SimpleMedicinesView()
                    case .medicineGroup(let id): SimpleMedicineGroupView(groupID: id)
                    case .plan: SimplePlanView()
                    case .planGroup(let id): SimplePlanGroupView(groupID: id)
                    case .ask: SimpleAskView()
                    case .help: SimpleHelpView()
                    case .warningSigns: SimpleWarningSignsView()
                    case .settings: SimpleSettingsView()
                    case .shareWithFamily: SimpleFamilyShareView()
                    }
                }
                .navigationDestination(for: MedicineInstruction.self) { medicine in
                    SimpleMedicineDetailView(medicine: medicine)
                }
                .navigationDestination(for: Appointment.self) { appointment in
                    SimpleVisitView(appointment: appointment)
                }
        }
    }
}

struct SimpleHomeView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only the "Done"
    @State private var undo: TodayUndo?

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = TodayViewModel(plan: plans.first, now: AppClock.now())
            FitOrScroll {
                VStack(alignment: .leading, spacing: Spacing.betweenCards) {
                    header(viewModel)

                    if viewModel.layout == .needsSurgeryDate {
                        SurgeryDatePrompt(viewModel: viewModel)
                    } else if let undo {
                        doneBanner(undo)
                    } else if viewModel.layout == .afterSurgery {
                        nowCard(viewModel)
                    } else {
                        stopCard(viewModel)
                    }

                    Spacer(minLength: 0)

                    tiles(viewModel)

                    HStack(spacing: 12) {
                        ReadAloudButton(title: "Read to me", text: viewModel.spokenSummary)
                        NavigationLink(value: SimpleRoute.settings) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 16)
            }
        }
        .background(Color.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .animation(Motion.animation(reduceMotion: reduceMotion), value: undo?.id)
        .task(id: undo?.id) {
            guard undo != nil else { return }
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { undo = nil }
        }
    }

    // MARK: - Header

    private func header(_ viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.headerTitle)
                .font(.largeTitle.bold())
            Text(viewModel.headerDetail)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Before surgery: what to stop

    private func stopCard(_ viewModel: TodayViewModel) -> some View {
        let card = viewModel.beforeTopCard
        return VStack(alignment: .leading, spacing: 14) {
            CardEyebrow(text: card.eyebrow, symbol: card.symbol, tone: card.tone)
                .font(.title3.weight(.semibold))
            Text(card.title)
                .font(.title.bold())
            ForEach(card.shortNames, id: \.self) { name in
                Label(name, systemImage: card.nameSymbol)
                    .font(.title3.weight(.semibold))
            }
            if !card.moreNamesText.isEmpty {
                Text(card.moreNamesText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if !card.detail.isEmpty {
                Text(card.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if let button = card.buttonTitle, !card.isDone {
                Button(button) {
                    Motion.perform(reduceMotion) { undo = viewModel.putAwayStopsToday(in: context) }
                }
                .buttonStyle(SimpleButtonStyle())
            } else if card.isDone {
                Label(card.doneText, systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Tone.good.color)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(card.tone.color, lineWidth: 3))
        .accessibilityElement(children: .contain)
    }

    // MARK: - After surgery: the dose to take now

    private func nowCard(_ viewModel: TodayViewModel) -> some View {
        let card = viewModel.nowCard
        return VStack(alignment: .leading, spacing: 14) {
            CardEyebrow(text: card.eyebrow, symbol: card.symbol, tone: card.tone)
                .font(.title3.weight(.semibold))
            Text(card.title)
                .font(.title.bold())
            ForEach(card.shortLines) { line in
                HStack(spacing: 14) {
                    MedicineIcon(pillShape: line.pillShape, pillColor: line.pillColor,
                                 symbol: "pills.fill", tone: card.tone, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.name).font(.title3.bold())
                        if !line.how.isEmpty {
                            Text(line.how).font(.body).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if !card.moreLinesText.isEmpty {
                Text(card.moreLinesText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if !card.detail.isEmpty {
                Text(card.detail)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if card.showsButtons {
                HStack(spacing: 12) {
                    Button {
                        Motion.perform(reduceMotion) { undo = viewModel.takeNow(in: context) }
                    } label: {
                        Label(viewModel.takeButtonTitle, systemImage: "checkmark")
                    }
                    .buttonStyle(SimpleButtonStyle())
                    .sensoryFeedback(.success, trigger: undo?.id)

                    Button(viewModel.skipButtonTitle) {
                        Motion.perform(reduceMotion) { undo = viewModel.skipNow(in: context) }
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
                    .frame(maxWidth: 120)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(card.tone.color, lineWidth: 3))
        .id(card.eyebrow + card.title)
        .transition(.push(from: .trailing))
    }

    // MARK: - "Done!" with a big Undo

    private func doneBanner(_ undo: TodayUndo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(undo.message, systemImage: "checkmark.circle.fill")
                .font(.title2.bold())
                .foregroundStyle(Tone.good.color)
            HStack(spacing: 12) {
                Button("Undo") {
                    Motion.perform(reduceMotion) {
                        undo.perform(context)
                        self.undo = nil
                    }
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain, height: 56))
                Button("OK") {
                    Motion.perform(reduceMotion) { self.undo = nil }
                }
                .buttonStyle(SimpleButtonStyle(height: 56))
            }
        }
        .padding(18)
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Tone.good.color, lineWidth: 3))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    // MARK: - The big buttons

    private func tiles(_ viewModel: TodayViewModel) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            NavigationLink(value: SimpleRoute.medicines) {
                SimpleTile(symbol: "pills.fill", title: "My medicines",
                           subtitle: viewModel.showsDoseProgress ? viewModel.doseProgress.text : "", style: .teal)
            }
            NavigationLink(value: SimpleRoute.plan) {
                SimpleTile(symbol: "calendar", title: "My plan", subtitle: "Visits, can and can\u{2019}t")
            }
            NavigationLink(value: SimpleRoute.ask) {
                SimpleTile(symbol: "bubble.left.and.text.bubble.right.fill", title: "Ask a question")
            }
            NavigationLink(value: SimpleRoute.help) {
                SimpleTile(symbol: "phone.fill", title: "Get help", subtitle: "Call someone", style: .red)
            }
        }
        .buttonStyle(.plain)
    }

}

#Preview("Before surgery", traits: .beforeSurgerySample) {
    SimpleRootView()
}

#Preview("After surgery", traits: .afterSurgerySample) {
    SimpleRootView()
}
