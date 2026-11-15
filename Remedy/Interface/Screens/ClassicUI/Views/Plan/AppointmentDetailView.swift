//
//  AppointmentDetailView.swift
//  Remedy
//
//  classic one visit (screen 40): when, call, directions and calendar, where, what to bring, the paper's words
//

import SwiftUI
import SwiftData

// classic visit page
struct AppointmentDetailView: View {
    let appointment: Appointment

    @Environment(\.dismiss) private var dismiss

    // UI only the edit screen
    @State private var isEditing = false
    // hides the visit while it is deleted
    @State private var isRemoved = false

    var body: some View {
        if isRemoved {
            RemedyBackground()
        } else {
            TimelineView(.everyMinute) { _ in
                content(AppointmentDetailViewModel(appointment: appointment, now: AppClock.now()))
            }
        }
    }

    private func content(_ viewModel: AppointmentDetailViewModel) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.title)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(viewModel.headerSubtitle)
                        .font(.body)
                        .foregroundStyle(Color.ink2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .plainListRow()
                VisitActionTiles(appointment: appointment)
                    .padding(.top, 12)
                    .plainListRow()
            }
            if !viewModel.infoRows.isEmpty {
                Section {
                    ForEach(viewModel.infoRows) { row in
                        ListRow(symbol: row.symbol, title: row.title, subtitle: row.subtitle)
                            .accessibilityElement(children: .combine)
                    }
                }
            }
            if viewModel.showsQuestions {
                Section {
                    ForEach(viewModel.questions, id: \.self) { ListRow(symbol: "questionmark.bubble", title: $0) }
                } header: {
                    ListSectionHeader(title: viewModel.questionsTitle)
                } footer: {
                    Text(viewModel.questionsFootnote).font(.footnote).foregroundStyle(Color.ink2)
                }
            }
            if !viewModel.quoteText.isEmpty {
                Section {
                    PaperQuote(source: viewModel.quoteSource, quote: viewModel.quoteText, plain: viewModel.quotePlain)
                        .plainListRow()
                }
            }
        }
        .remedyList()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if appointment.plan != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(viewModel.editTitle) { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            if let plan = appointment.plan {
                AppointmentEditView(appointment: appointment, plan: plan, now: AppClock.now()) {
                    isRemoved = true
                    dismiss()
                }
            }
        }
    }
}

#Preview("A visit", traits: .afterSurgerySample) {
    PlanView()
}
