//
//  PapersView.swift
//  Remedy
//
//  classic papers (screen 46), one paper (screen 47) and what changed (screen 48)
//

import SwiftUI
import SwiftData

// classic papers page
struct PapersView: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Query private var checkNotes: [PaperCheckNote]

    // UI only adding papers and what is open
    @State private var isAdding = false
    @State private var openPaper: Paper?
    @State private var showsChanged = false
    @State private var showsNotes = false
    @State private var disagree: String?

    var body: some View {
        let screen = PapersScreen(plan: plans.first, now: AppClock.now())
        List {
            if !screen.disagreeCards.isEmpty {
                Section {
                    ForEach(screen.disagreeCards) { card in
                        Button { disagree = card.id } label: {
                            ListRow(symbol: "exclamationmark.triangle", tone: .stop, title: screen.disagreeTitle,
                                    subtitle: card.headline, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .toneRow(.stop)
            }
            if let changed = screen.changedTitle {
                Section {
                    Button { showsChanged = true } label: {
                        ListRow(symbol: "sparkles", tone: .caution, title: changed, subtitle: screen.changedSubtitle,
                                showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                .toneRow(.caution)
            }
            Section {
                if screen.papers.isEmpty {
                    Text(screen.emptyText).font(.body).foregroundStyle(Color.ink2)
                }
                ForEach(screen.papers) { paper in
                    Button { openPaper = paper } label: {
                        ListRow(symbol: "doc.text", title: PapersScreen.title(paper), subtitle: screen.subtitle(paper),
                                showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                if screen.noteCount > 0 {
                    Button { showsNotes = true } label: {
                        ListRow(symbol: "note.text", title: screen.notesTitle, value: "\(screen.noteCount)", showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                ListSectionHeader(title: screen.listTitle)
            }
            Section {
                Button { isAdding = true } label: {
                    ListRow(symbol: "plus", title: screen.addTitle, subtitle: screen.addSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)
            } footer: {
                Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(item: $openPaper) { PaperView(paper: $0) }
        .navigationDestination(isPresented: $showsChanged) { WhatChangedPage() }
        .navigationDestination(isPresented: $showsNotes) { PlanPageView(page: .paperNotes) }
        .navigationDestination(item: $disagree) { id in
            if let card = screen.disagreeCards.first(where: { $0.id == id }) { PapersDisagreeView(card: card) }
        }
        .sheet(isPresented: $isAdding) {
            ScanFlowView(isAddingPapers: true, planHasSurgeryDate: plans.first?.surgeryDate != nil)
        }
    }
}

// one paper (screen 47)
struct PaperView: View {
    let paper: Paper

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.switchTab) private var switchTab

    // UI only the delete question and what is open
    @State private var isConfirmingDelete = false
    @State private var showsChanged = false
    @State private var isRemoved = false

    var body: some View {
        if isRemoved {
            RemedyBackground()
        } else {
            content(PaperScreen(paper: paper, plan: plans.first, now: AppClock.now()))
        }
    }

    private func content(_ screen: PaperScreen) -> some View {
        List {
            Section {
                Text(screen.subtitle)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
                    .plainListRow()
                if !screen.pageNumbers.isEmpty {
                    PageTiles(numbers: screen.pageNumbers, word: screen.pageWord)
                        .padding(.top, 8)
                        .plainListRow()
                }
            }
            Section {
                Button { switchTab?(.medicines) } label: {
                    ListRow(symbol: "pills", title: screen.medicinesTitle, subtitle: screen.medicinesSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    ListRow(symbol: "list.bullet", title: screen.planTitle, subtitle: screen.planSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)
                if screen.showsChanged {
                    Button { showsChanged = true } label: {
                        ListRow(symbol: "sparkles", title: screen.changedTitle, subtitle: screen.changedSubtitle, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                ListSectionHeader(title: screen.fromTitle)
            }
            Section {
                Button(screen.deleteTitle, role: .destructive) { isConfirmingDelete = true }
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
            } footer: {
                Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showsChanged) { WhatChangedPage() }
        .confirmationDialog(screen.deleteTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(screen.deleteTitle, role: .destructive) {
                isRemoved = true
                if let plan = plans.first { PaperActions.remove(paper, from: plan, in: context) }
                dismiss()
            }
        } message: {
            Text(screen.deleteMessage)
        }
    }
}

// the pages of a paper; the photos are never kept, so each page shows as a page tile
struct PageTiles: View {
    let numbers: [Int]
    let word: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let across = typeSize.isAccessibilitySize ? 2 : 3
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: across), spacing: 12) {
            ForEach(numbers, id: \.self) { number in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(Color.cardBackground)
                        .aspectRatio(8.5 / 11, contentMode: .fit)
                        .overlay {
                            Image(systemName: "doc.text").font(.title).foregroundStyle(Color.ink3)
                        }
                        .accessibilityHidden(true)
                    Text("\(word) \(number)").font(.body).foregroundStyle(Color.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(word) \(number)")
            }
        }
    }
}

// what changed (screen 48) for the newest paper
struct WhatChangedPage: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let changes = WhatChangedViewModel(plan: plans.first) {
            WhatChangedView(viewModel: changes, intro: WhatChangedViewModel.intro(plan: plans.first),
                            footer: WhatChangedViewModel.footer(plan: plans.first)) { dismiss() }
        }
    }
}
