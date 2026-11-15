//
//  MedicineDetailView.swift
//  Remedy
//
//  classic one medicine (screens 32 33 35): the answer card, today's doses, facts, the paper's words
//

import SwiftUI
import SwiftData

// where a row on the detail goes
private enum DetailRoute: Hashable {
    case disagree(String)
    case visit(Appointment)
    case doseLog
    case medicine(MedicineInstruction)
}

// classic medicine page
struct MedicineDetailView: View {
    let medicine: MedicineInstruction

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // UI only which sheet, dialog or page is showing, and hiding the medicine while it is deleted
    @State private var isEditing = false
    @State private var isShowingSource = false
    @State private var isLookingWrong = false
    @State private var isLoggingEarlier = false
    @State private var isRestarting = false
    @State private var restart: RestartPick?
    @State private var route: DetailRoute?
    @State private var isRemoved = false
    // redraws when a dose is logged or the office's answer is saved
    @Query private var logs: [DoseLog]
    @Query private var checkNotes: [PaperCheckNote]

    var body: some View {
        if isRemoved {
            RemedyBackground()
        } else {
            TimelineView(.everyMinute) { _ in
                content(MedicineDetailViewModel(medicine: medicine, now: AppClock.now()))
            }
        }
    }

    private func content(_ screen: MedicineDetailViewModel) -> some View {
        List {
            Section {
                if let card = screen.card {
                    ActionCard(style: card.style == .good ? .good : (card.style == .stop ? .stop : .caution),
                               eyebrow: card.eyebrow, eyebrowSymbol: card.symbol, title: card.title, text: card.text) {
                        VStack {
                            if !card.button.isEmpty {
                            PrimaryButton(title: card.button, symbol: "checkmark") {
                                Motion.perform(reduceMotion) { screen.logAsNeeded(in: context) }
                            }
                            .padding(.top, 8)
                            }
                        }
                    }
                    .plainListRow()
                }
            } header: {
                header(screen)
            }

            if !screen.todayRows.isEmpty {
                Section {
                    ForEach(screen.todayRows) { line in
                        ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                                subtitleTone: line.subtitleTone) {
                            if let slot = line.dose, slot.state == .due || slot.state == .missed {
                                Button(screen.logTookButton) {
                                    Motion.perform(reduceMotion) { screen.setAnswer(.taken, for: slot, in: context) }
                                }
                                .buttonStyle(CapsuleFillStyle(fill: .accentFill, text: .onAccent))
                                .font(.body.weight(.semibold))
                            }
                        }
                    }
                } header: {
                    ListSectionHeader(title: screen.todayTitle)
                }
            }

            Section {
                ForEach(screen.factRows) { row($0, screen: screen) }
            }

            if screen.hasPaperQuote {
                Section {
                    PaperQuote(source: screen.quoteHeader, quote: screen.quoteText, plain: screen.quotePlain)
                        .plainListRow()
                }
            }

            // 95, right after the quote
            if !screen.relatedLines.isEmpty {
                Section {
                    ForEach(screen.relatedLines) { row($0, screen: screen) }
                } header: {
                    ListSectionHeader(title: screen.relatedHeader)
                } footer: {
                    Text(screen.relatedNote).font(.footnote).foregroundStyle(Color.ink2)
                }
            }

            if let restartRow = screen.restartRow {
                Section { row(restartRow, screen: screen) }
            }
            if let logRow = screen.doseLogRow {
                Section { row(logRow, screen: screen) }
            }

            if screen.kind == .asNeeded {
                Section {
                    ForEach(screen.takenRows) { line in
                        ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle)
                    }
                    // kept from before the redesign, for a dose taken without logging it
                    Button { isLoggingEarlier = true } label: {
                        ListRow(symbol: "plus", title: screen.earlierDoseTitle, subtitle: screen.logEarlierText, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } header: {
                    ListSectionHeader(title: screen.takenHeader)
                }
            }

        }
        .remedyList()
        .navigationTitle(screen.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // the big name in the list is the title, the bar stays clear
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1).accessibilityHidden(true) }
            if screen.showsEdit {
                ToolbarItem(placement: .topBarTrailing) { Button(screen.editButton) { isEditing = true } }
            }
        }
        .navigationDestination(item: $route) { destination($0) }
        .confirmationDialog(screen.lookWrongTitle, isPresented: $isLookingWrong, titleVisibility: .hidden) {
            Button(screen.showWordsButton) { isShowingSource = true }
            if medicine.plan != nil { Button(screen.fixButton) { isEditing = true } }
            if let call = screen.pharmacyCall { Button(screen.callPharmacyButton) { openURL(call) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(screen.lookWrongMessage)
        }
        .sheet(isPresented: $isEditing) {
            if let plan = medicine.plan {
                MedicineEditView(medicine: medicine, plan: plan, now: AppClock.now(), onDeleted: {
                    isRemoved = true
                    dismiss()
                })
            }
        }
        .sheet(isPresented: $isShowingSource) {
            let old = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
            SourceQuoteSheet(data: old.sourceQuote, report: old.mistakeReport, title: old.quoteSheetTitle)
        }
        .sheet(isPresented: $isLoggingEarlier) {
            EarlierDoseSheet(viewModel: MedicineDetailViewModel(medicine: medicine, now: AppClock.now()))
        }
        // who said OK first, then the edit form for the new line
        .sheet(isPresented: $isRestarting) {
            RestartSheet(medicineName: medicine.name) { who, date in restart = RestartPick(who: who, date: date) }
        }
        .sheet(item: $restart) { pick in
            if let plan = medicine.plan {
                MedicineEditView(medicine: nil, plan: plan, now: AppClock.now(), preset: restartDraft(pick, plan: plan), onSaved: { newLine in
                    MedicineActions.finishRestart(stop: medicine, newLine: newLine, who: pick.who, on: pick.date, context: context)
                })
            }
        }
    }

    // the name big, then what kind of medicine it is
    private func header(_ screen: MedicineDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(screen.pageTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !screen.pageSubtitle.isEmpty {
                Text(screen.pageSubtitle)
                    .font(.body)
                    .foregroundStyle(Color.ink2)
            }
        }
        .textCase(nil)
        .padding(.leading, -16)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func row(_ line: MedicineDetailLine, screen: MedicineDetailViewModel) -> some View {
        let label = ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                            subtitleTone: line.subtitleTone, showsChevron: line.opens)
        if line.opens {
            Button { open(line.target) } label: { label }
                .buttonStyle(.plain)
        } else {
            label
        }
    }

    private func open(_ target: MedicineDetailLine.Target) {
        switch target {
        case .none: break
        case .disagree:
            if let card = PaperCheckViewModel(plan: medicine.plan, now: AppClock.now()).redCards(for: medicine).first {
                route = .disagree(card.id)
            }
        case .visit(let visit): route = .visit(visit)
        case .lookWrong: isLookingWrong = true
        case .doseLog: route = .doseLog
        case .restart: isRestarting = true
        case .related(let other): route = .medicine(other)
        }
    }

    @ViewBuilder
    private func destination(_ route: DetailRoute) -> some View {
        switch route {
        case .disagree(let id):
            if let card = PaperCheckViewModel(plan: medicine.plan, now: AppClock.now()).redCards.first(where: { $0.id == id }) {
                PapersDisagreeView(card: card)
            }
        case .visit(let visit): AppointmentDetailView(appointment: visit)
        case .doseLog: DoseLogView(medicine: medicine)
        case .medicine(let other): MedicineDetailView(medicine: other)
        }
    }

    // the new line starts from the stopped one's name and amount, on the picked day
    private func restartDraft(_ pick: RestartPick, plan: CarePlan) -> MedicineDraft {
        var draft = MedicineDraft(name: MedicineText.everydayName(medicine), amount: medicine.amount, times: [8 * 60])
        draft.action = .take
        draft.startDay = plan.surgeryDate.map { DayMath.dayOffset(of: pick.date, from: $0) }
        return draft
    }

}

// who said OK and when, carried from the restart sheet to the edit form
struct RestartPick: Identifiable {
    let who: String
    let date: Date
    var id: Date { date }
}

// MARK: - Earlier dose

// pick when an as-needed dose was taken earlier today
struct EarlierDoseSheet: View {
    let viewModel: MedicineDetailViewModel
    var large = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MedicineText.fullName(everyday: viewModel.medicine))
                        .font(large ? .title.bold() : .title2.bold())
                        .foregroundStyle(Color.ink)
                    Text(viewModel.earlierDoseQuestion)
                        .font(large ? .title3 : .body)
                        .foregroundStyle(Color.ink2)
                }
                DatePicker(viewModel.earlierDoseQuestion, selection: $time, in: viewModel.earlierDoseRange,
                           displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Color.cardBackground))
                Text(viewModel.earlierDoseFooter)
                    .font(.footnote)
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, large ? Spacing.simpleEdge : Spacing.screenEdge)
            .background(Color.screenBackground)
            .formSheetChrome(title: viewModel.earlierDoseTitle, saveTitle: viewModel.earlierDoseSave,
                             onClose: { dismiss() }, onSave: {
                                 viewModel.logEarlier(at: time, in: context)
                                 dismiss()
                             })
            .onAppear { time = viewModel.now }
        }
        .presentationDetents([.large])
    }
}
