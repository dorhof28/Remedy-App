//
//  SimplePlanView.swift
//  Remedy
//
//  simple plan pages: instructions and one visit
//

import SwiftUI
import SwiftData

// instructions: read to me, then one big card per topic with every line and its mark
struct SimplePlanRulesView: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the line whose paper words are open
    @State private var quoted: ReminderRow?

    var body: some View {
        let viewModel = PlanViewModel(plan: plans.first, now: AppClock.now())
        let now = viewModel.instructionGroups(.now)
        let later = viewModel.instructionGroups(.later)
        SimpleScreen(title: viewModel.simpleDosTitle, readAloud: viewModel.instructionsSpoken(.all)) {
            if now.isEmpty && later.isEmpty {
                Text(viewModel.instructionsEmptyText)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            } else {
                Text(viewModel.simpleDosIntro)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
            }
            ForEach(now) { group in
                InstructionTopicCard(group: group, large: true) { quoted = $0 }
            }
            if !later.isEmpty {
                SimpleSectionTitle(title: viewModel.simpleLaterTitle, tone: .info, symbol: "calendar.badge.clock")
                ForEach(later) { group in
                    InstructionTopicCard(group: group, large: true) { quoted = $0 }
                }
            }
        }
        .sheet(item: $quoted) { row in
            PlanQuoteSheet(title: row.text, quote: row.quote, source: row.source, large: true)
        }
    }
}

// the right edit screen for a tapped target
struct SimplePlanEditor: View {
    let target: PlanEditTarget
    let plan: CarePlan

    var body: some View {
        switch target {
        case .medicine(let medicine): SimpleMedicineEditView(medicine: medicine, plan: plan, now: AppClock.now())
        case .visit(let visit): SimpleAppointmentEditView(appointment: visit, plan: plan, now: AppClock.now())
        case .task(let task): SimpleTaskEditView(task: task, plan: plan, now: AppClock.now())
        }
    }
}

// MARK: - One group

// MARK: - One visit

// one visit, bigger: when, where with directions and calendar, who with call and text, notes, the paper
struct SimpleVisitView: View {
    let appointment: Appointment

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    // UI only Apple's "New Event" screen, the edit screen and the quote
    @State private var isAddingToCalendar = false
    @State private var isEditing = false
    @State private var showsQuote = false
    // hides the visit while it is deleted
    @State private var isRemoved = false

    var body: some View {
        if isRemoved {
            RemedyBackground()
        } else {
            content
        }
    }

    private var content: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = AppointmentDetailViewModel(appointment: appointment, now: AppClock.now())
            SimpleScreen(title: viewModel.title,
                         readAloud: [viewModel.whenText, viewModel.placeTitle, viewModel.purpose].filter { !$0.isEmpty }.joined(separator: ". ")) {
                Text(viewModel.whenText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentInk)

                // where, with the two big place buttons
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.placeTitle.isEmpty ? viewModel.noPlaceText : viewModel.placeTitle)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(viewModel.placeTitle.isEmpty ? Color.ink2 : Color.ink)
                        if !viewModel.placeDetail.isEmpty {
                            Text(viewModel.placeDetail).font(.body).foregroundStyle(Color.ink2)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if let mapsURL = viewModel.mapsURL {
                        Link(destination: mapsURL) { Label(viewModel.directionsTitle, systemImage: "map") }
                            .buttonStyle(SimpleButtonStyle())
                    }
                    if viewModel.showsCalendarButton {
                        Button {
                            isAddingToCalendar = true
                        } label: {
                            Label(viewModel.calendarButtonTitle, systemImage: viewModel.calendarButtonSymbol)
                        }
                        .buttonStyle(SimpleButtonStyle(kind: .plain))
                        .disabled(!viewModel.canAddToCalendar)
                        .sheet(isPresented: $isAddingToCalendar) {
                            CalendarEventSheet(event: viewModel.calendarEvent(), onDone: { _ in
                                isAddingToCalendar = false
                            }, onSaved: { id in
                                viewModel.markAddedToCalendar(eventID: id, in: context)
                            })
                            .ignoresSafeArea()
                        }
                    }
                }
                .padding(Spacing.insideCard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                if viewModel.showsDoctor {
                    SimplePlanRow(kind: .custom(symbol: "person", tone: .neutral), title: viewModel.doctorName,
                                  detail: viewModel.doctorDetail) {
                        if viewModel.phoneURL != nil {
                            ContactCapsule(name: viewModel.doctorName, phoneURL: viewModel.phoneURL,
                                           messageURL: viewModel.messageURL, large: true)
                        }
                    }
                }

                if viewModel.showsPurpose {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.whyTitle).font(.headline).foregroundStyle(Color.ink2)
                        Text(viewModel.purpose).font(.title3).foregroundStyle(Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.insideCard)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .accessibilityElement(children: .combine)
                }

                // what to bring and what to ask, right here so there is no page under a page
                if viewModel.showsBring {
                    SimpleLinesCard(title: viewModel.bringTitle, items: viewModel.bringItems, symbol: "bag")
                }
                if viewModel.showsQuestions {
                    SimpleLinesCard(title: viewModel.questionsTitle, items: viewModel.questions, symbol: "questionmark.bubble")
                }

                if viewModel.showsSource {
                    SourceRow(title: viewModel.sourceTitle, detail: viewModel.sourceDetail,
                              action: viewModel.quote.isEmpty ? nil : Optional({ showsQuote = true }))
                }

                if appointment.plan != nil {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Change this visit", systemImage: "pencil")
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
                }
            }
        }
        .sheet(isPresented: $showsQuote) {
            PlanQuoteSheet(title: appointment.title, quote: appointment.quote,
                           source: AppointmentDetailViewModel(appointment: appointment, now: AppClock.now()).quoteSource, large: true)
        }
        .sheet(isPresented: $isEditing) {
            if let plan = appointment.plan {
                SimpleAppointmentEditView(appointment: appointment, plan: plan, now: AppClock.now()) {
                    isRemoved = true
                    dismiss()
                }
            }
        }
    }
}

// MARK: - A short list of sentences ("Bring", "Questions to ask") in one card

struct SimpleLinesCard: View {
    let title: String
    let items: [String]
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.title3.bold())
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(Color.ink2)
                        .accessibilityHidden(true)
                    Text(line)
                        .font(.title3)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Spacing.insideCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

