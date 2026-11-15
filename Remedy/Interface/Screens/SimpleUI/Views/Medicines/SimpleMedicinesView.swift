//
//  SimpleMedicinesView.swift
//  Remedy
//
//  simple medicines (81): one big card per medicine, and every medicine by group behind All Medicines
//

import SwiftUI
import SwiftData

// every medicine in big rows
struct SimpleAllMedicinesView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only is the add screen open
    @State private var isAdding = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = MedicinesViewModel(plan: plans.first, now: AppClock.now())
            // the same section order the patient picked in the classic look
            let order = UserDefaults.standard.string(forKey: MedicinesViewModel.orderKey(for: plans.first)) ?? ""
            let sections = viewModel.listSections(order: order)
            SimpleScreen(title: "All Medicines",
                         readAloud: sections.map(\.spokenCount).joined(separator: ". ")) {
                if viewModel.isEmpty {
                    Text(viewModel.emptyDetail)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                }
                ForEach(sections) { section in
                    group(section)
                }
                if plans.first != nil {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add a Medicine", systemImage: "plus")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .gray))
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            if let plan = plans.first {
                SimpleMedicineEditView(medicine: nil, plan: plan, now: AppClock.now())
            }
        }
    }

    // 111 a coloured header, then the group's rows in one card
    @ViewBuilder
    private func group(_ section: MedicineSection) -> some View {
        Label {
            Text(section.title)
        } icon: {
            if section.tone == .stop { Image(systemName: "nosign") }
        }
        .font(.title2.weight(.bold))
        .foregroundStyle(section.tone == .stop ? Color.dangerInk : Color.ink2)
        .padding(.top, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.spokenCount)
        .accessibilityAddTraits(.isHeader)

        VStack(spacing: 0) {
            // record medicines no paper names: ask your care team
            ForEach(section.gaps) { gap in
                bigRow(title: gap.name, subtitle: gap.detail, showsChevron: false) {
                    ItemIconTile(kind: MedicineListSection.gaps.kind, size: 44)
                }
                Divider().padding(.leading, 74)
            }
            ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                NavigationLink(value: row.medicine) {
                    bigRow(title: row.title, subtitle: section.tone == .stop ? "" : SimpleWording.plain(row.subtitle)) {
                        ItemIconTile(kind: row.kind, size: 44)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SimpleWording.plain(row.spokenLabel))
                if index < section.rows.count - 1 { Divider().padding(.leading, 74) }
            }
        }
        .cardStyle()
    }

    private func bigRow<Icon: View>(title: String, subtitle: String, showsChevron: Bool = true,
                                    @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 14) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3).foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.body).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(Color.ink3)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: Spacing.tapSimple)
        .contentShape(Rectangle())
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleMedicinesView() }
}

// MARK: - 81 one big card per medicine with what to do now

// simple medicines: what to take now and what not to take
struct SimpleMedicinesView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    // redraws the cards when the office's answer is saved
    @Query private var checkNotes: [PaperCheckNote]

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let screen = SimpleMedicinesScreen(plan: plans.first, now: AppClock.now())
            // papers that disagree are never hidden, they come first
            let red = PaperCheckViewModel(plan: plans.first, now: AppClock.now()).redCards
            SimpleScreen(title: screen.title) {
                if !red.isEmpty { SimpleDisagreementCard(cards: red) }
                if screen.cards.isEmpty {
                    Text(screen.emptyText)
                        .font(.title3)
                        .foregroundStyle(Color.ink2)
                }
                ForEach(screen.cards) { card in
                    if let medicine = card.medicine {
                        NavigationLink(value: medicine) { cardView(card) }
                            .buttonStyle(.plain)
                    } else {
                        NavigationLink { SimpleAllMedicinesView() } label: { cardView(card) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func cardView(_ card: SimpleMedicineCard) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.title)
                .font(.title2.bold())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            if card.tone == .stop {
                Label(card.status, systemImage: "nosign")
                    .font(.title3)
                    .foregroundStyle(Color.dangerInk)
            } else {
                Text(card.status)
                    .font(.title3)
                    .foregroundStyle(card.tone == .neutral ? Color.ink2 : (card.tone == .good ? Tone.good.color : Color.accentInk))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .simpleOutlineCard(isNext: card.isNow, tone: card.tone == .stop ? .stop : nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
