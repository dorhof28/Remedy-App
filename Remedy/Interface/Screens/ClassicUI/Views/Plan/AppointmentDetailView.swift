//
//  AppointmentDetailView.swift
//  Remedy
//
//  classic one visit
//

import SwiftUI
import SwiftData

struct AppointmentDetailView: View {
    let appointment: Appointment

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only is Apple's "New Event" screen open
    @State private var isAddingToCalendar = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            let viewModel = AppointmentDetailViewModel(appointment: appointment, now: AppClock.now())
            ScrollView {
                VStack(spacing: Spacing.betweenCards) {
                    let parts = viewModel.dateParts
                    TopCard(title: viewModel.title, subtitle: viewModel.subtitle, caption: viewModel.relativeText) {
                        DateTile(month: parts.month, day: parts.day, weekday: parts.weekday, size: 84)
                    }

                    buttons(viewModel)

                    if viewModel.showsDetails {
                        SectionCard(title: viewModel.detailsTitle, symbol: "info.circle", rememberAs: "visit.details") {
                            DividedList(items: viewModel.detailRows, inset: 42) { row in
                                IconRow(symbol: row.symbol, title: row.title, subtitle: row.subtitle)
                            }
                        }
                    }

                    if viewModel.showsWhy {
                        SectionCard(title: viewModel.whyTitle, symbol: "questionmark.circle", rememberAs: "visit.why") {
                            VStack(alignment: .leading, spacing: 14) {
                                if viewModel.showsPurpose {
                                    Text(viewModel.purpose)
                                        .font(.subheadline)
                                }
                                PaperQuoteCard(quote: viewModel.quote, source: viewModel.quoteSource)
                            }
                            .padding(.vertical, Spacing.rowVertical)
                        }
                    }

                    if viewModel.showsBring {
                        SectionCard(title: viewModel.bringTitle, symbol: "bag", rememberAs: "visit.bring") {
                            BulletList(items: viewModel.bringItems, symbol: "checkmark.circle")
                        }
                    }

                    if viewModel.showsQuestions {
                        SectionCard(title: viewModel.questionsTitle, symbol: "text.bubble",
                                    startsExpanded: false, rememberAs: "visit.questions") {
                            BulletList(items: viewModel.questions, symbol: "questionmark.circle")
                            CardFootnote(text: viewModel.questionsFootnote)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Calendar, Call, Directions

    private func buttons(_ viewModel: AppointmentDetailViewModel) -> some View {
        VStack(spacing: 10) {
            if viewModel.showsCalendarButton {
                Button {
                    isAddingToCalendar = true
                } label: {
                    Label(viewModel.calendarButtonTitle, systemImage: viewModel.calendarButtonSymbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canAddToCalendar)
                .sensoryFeedback(.success, trigger: viewModel.isInCalendar) { _, isIn in isIn }
                .sheet(isPresented: $isAddingToCalendar) {
                    CalendarEventSheet(event: viewModel.calendarEvent()) { added in
                        if added { Motion.perform(reduceMotion) { viewModel.markAddedToCalendar(in: context) } }
                        isAddingToCalendar = false
                    }
                    .ignoresSafeArea()
                }
            }

            if viewModel.showsContactButtons {
                HStack(spacing: 10) {
                    CallButton(title: viewModel.callTitle, phoneURL: viewModel.phoneURL)
                    if let mapsURL = viewModel.mapsURL {
                        Link(destination: mapsURL) {
                            Label(viewModel.directionsTitle, systemImage: "map.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .controlSize(.large)
    }
}

#Preview("A visit", traits: .afterSurgerySample) {
    PlanView()
}
