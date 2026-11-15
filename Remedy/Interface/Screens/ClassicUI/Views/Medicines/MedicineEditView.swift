//
//  MedicineEditView.swift
//  Remedy
//
//  classic add or change a medicine, the shared grouped form
//

import SwiftUI
import SwiftData

// classic medicine edit form
struct MedicineEditView: View {
    @State private var viewModel: MedicineEditViewModel
    // the screen showing the medicine hides it before it is deleted
    var onDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focus: MedicineEditViewModel.Field?
    // UI only which check is showing
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDiscard = false

    // after a restart line is saved, the caller ends the stop
    var onSaved: ((MedicineInstruction) -> Void)?

    init(medicine: MedicineInstruction?, plan: CarePlan, now: Date, preset: MedicineDraft? = nil,
         onDeleted: (() -> Void)? = nil, onSaved: ((MedicineInstruction) -> Void)? = nil) {
        _viewModel = State(initialValue: MedicineEditViewModel(medicine: medicine, plan: plan, now: now, preset: preset))
        self.onDeleted = onDeleted
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollViewReader { scroller in
                List {
                    Section {
                        fieldRow(symbol: "pills", label: viewModel.nameLabel, prompt: viewModel.namePrompt,
                                 text: $viewModel.draft.name, field: .name, words: true)
                            .id("name")
                        if let problem = viewModel.problem(for: .name) { FieldProblemText(text: problem) }
                        fieldRow(symbol: "list.bullet", label: viewModel.amountLabel, prompt: viewModel.amountPrompt,
                                 text: $viewModel.draft.amount, field: .amount, words: false)
                    }

                    Section {
                        Picker(selection: $viewModel.draft.action) {
                            ForEach(viewModel.groupOptions, id: \.self) { Text(viewModel.groupTitle(for: $0)).tag($0) }
                        } label: {
                            ListRow(symbol: "list.bullet", title: viewModel.groupLabel) { EmptyView() }
                        }
                        .pickerStyle(.navigationLink)
                        NavigationLink {
                            TextFieldPage(title: viewModel.purposeLabel, text: $viewModel.draft.purpose,
                                          prompt: viewModel.purposePrompt)
                        } label: {
                            ListRow(symbol: "info.circle", title: viewModel.purposeLabel,
                                    value: viewModel.draft.purpose.isEmpty ? viewModel.notSetText : viewModel.draft.purpose)
                        }
                        if viewModel.draft.usesTimes {
                            NavigationLink {
                                timesPage
                            } label: {
                                ListRow(symbol: "clock", title: viewModel.timesLabel,
                                        subtitle: viewModel.timesText.isEmpty ? viewModel.notSetText : viewModel.timesText) { EmptyView() }
                            }
                            .id("times")
                            if let problem = viewModel.problem(for: .times) { FieldProblemText(text: problem) }
                        }
                        if viewModel.canEditDates {
                            dateRow(viewModel.startLabel, isOn: $viewModel.hasStart, date: $viewModel.startDate)
                            dateRow(viewModel.stopLabel, isOn: $viewModel.hasEnd, date: $viewModel.endDate)
                                .id("dates")
                            if let problem = viewModel.problem(for: .dates) { FieldProblemText(text: problem) }
                        }
                    } header: {
                        ListSectionHeader(title: viewModel.actionTitle)
                    } footer: {
                        Text(viewModel.groupsFooter)
                            .font(.subheadline)
                            .foregroundStyle(Color.ink2)
                    }

                    if viewModel.draft.action == .takeAsNeeded { limitsSection }

                    Section {
                        TextField(viewModel.notesRowPrompt, text: $viewModel.draft.notes, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focus, equals: .notes)
                            .frame(minHeight: Spacing.minTarget)
                    }

                    if !viewModel.isNew {
                        Section {
                            Button(role: .destructive) { isConfirmingDelete = true } label: {
                                Text(viewModel.deleteRowTitle)
                                    .foregroundStyle(Color.dangerInk)
                                    .frame(maxWidth: .infinity, minHeight: Spacing.minTarget)
                            }
                        }
                    }
                }
                .remedyList()
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.showsProblems) { _, shows in
                    // save stays on, it scrolls to the first problem
                    guard shows else { return }
                    if viewModel.problem(for: .name) != nil { scroller.scrollTo("name") }
                    else if viewModel.problem(for: .times) != nil { scroller.scrollTo("times") }
                    else if viewModel.problem(for: .dates) != nil { scroller.scrollTo("dates") }
                }
            }
            .formSheetChrome(title: viewModel.title, saveTitle: viewModel.saveTitle, onClose: close, onSave: save)
            .keyboardStepper(focus: $focus, title: { viewModel.keyboardButtonTitle(for: $0) }, advance: advance)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .confirmationDialog(viewModel.discardTitle, isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog(viewModel.deleteRowTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(viewModel.deleteRowTitle, role: .destructive) {
                    onDeleted?()
                    dismiss()
                    viewModel.delete(in: context)
                }
            } message: {
                Text(viewModel.deleteMessage)
            }
        }
        .presentationDetents([.large])
    }

    // icon, label, and the typed value on the right
    private func fieldRow(symbol: String, label: String, prompt: String, text: Binding<String>,
                          field: MedicineEditViewModel.Field, words: Bool) -> some View {
        ListRow(symbol: symbol, title: label) {
            TextField(prompt, text: text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(words ? .words : .never)
                .autocorrectionDisabled(words)
                .focused($focus, equals: field)
                .submitLabel(viewModel.submitLabel(for: field))
                .onSubmit { advance(field) }
                .foregroundStyle(Color.ink2)
        }
    }

    // start or stop: a switch for no date, then the day
    private func dateRow(_ title: String, isOn: Binding<Bool>, date: Binding<Date>) -> some View {
        ListRow(symbol: "calendar", title: title) {
            if isOn.wrappedValue {
                DatePicker(title, selection: date, displayedComponents: .date)
                    .labelsHidden()
                Button { isOn.wrappedValue = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ink3)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(title) date")
            } else {
                Button("Add Date") { isOn.wrappedValue = true }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentInk)
            }
        }
    }

    // 97, the times, pushed from the times row
    private var timesPage: some View {
        @Bindable var viewModel = viewModel
        return List {
            Section {
                ForEach(viewModel.draft.times.indices, id: \.self) { index in
                    HStack(spacing: 14) {
                        Button { viewModel.removeTime(at: index) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.dangerInk)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(viewModel.removeTimeLabel(index))
                        // the system time wheel opens in place
                        DatePicker(viewModel.timesPageTitle, selection: Binding(
                            get: { viewModel.time(at: index) },
                            set: { viewModel.setTime($0, at: index) }), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Spacer()
                    }
                    .frame(minHeight: Spacing.minTarget)
                }
                Button { viewModel.addTime() } label: {
                    ListRow(symbol: "plus", title: viewModel.addATime)
                }
                .buttonStyle(.plain)
            } footer: {
                Text(viewModel.draft.times.isEmpty ? viewModel.noTimesFooter : viewModel.timesFooter)
                    .font(.footnote)
                    .foregroundStyle(viewModel.draft.times.isEmpty ? Tone.caution.color : Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(viewModel.timesPageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    // 96, only-when-needed limits that the can I take it now card uses
    private var limitsSection: some View {
        Section {
            limitRow(viewModel.hoursLimitTitle, value: viewModel.minHoursValue, problem: viewModel.problem(for: .minHours)) {
                viewModel.stepHours($0)
            }
            limitRow(viewModel.mostLimitTitle, value: viewModel.maxPerDayValue, problem: viewModel.problem(for: .maxPerDay)) {
                viewModel.stepMax($0)
            }
        } header: {
            ListSectionHeader(title: viewModel.limitsHeader)
        } footer: {
            Text(viewModel.limitsFooter).font(.footnote).foregroundStyle(Color.ink2)
        }
    }

    private func limitRow(_ title: String, value: Int?, problem: String?, step: @escaping (Bool) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Stepper {
                Text("\(title): \(Text(value.map { "\($0)" } ?? viewModel.notSetText).bold())")
            } onIncrement: { step(true) } onDecrement: { step(false) }
            .frame(minHeight: Spacing.minTarget)
            if let problem { FieldProblemText(text: problem) }
        }
    }

    private func stepper(_ title: String, value: Int?, problem: String?, step: @escaping (Bool) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FormStepperRow(title: title, valueText: value.map { "\($0)" } ?? viewModel.notSetText,
                           canGoDown: value != nil, step: step)
            if let problem { FieldProblemText(text: problem) }
        }
        .listRowBackground(FieldProblemBackground(hasProblem: problem != nil))
    }

    // MARK: - Actions

    // For is a pushed page here, so the keyboard skips it
    private func advance(_ field: MedicineEditViewModel.Field) {
        let next = viewModel.nextField(after: field)
        focus = next == .purpose ? viewModel.nextField(after: .purpose) : next
    }

    // asks before throwing away changes
    private func close() {
        if viewModel.hasChanges { isConfirmingDiscard = true } else { dismiss() }
    }

    private func save() {
        if viewModel.save(in: context) {
            if let line = viewModel.savedLine { onSaved?(line) }
            dismiss()
        } else if viewModel.problem(for: .name) != nil {
            focus = .name
        }
    }
}
