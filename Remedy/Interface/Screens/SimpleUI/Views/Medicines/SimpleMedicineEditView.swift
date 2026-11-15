//
//  SimpleMedicineEditView.swift
//  Remedy
//
//  simple add or change a medicine, the big version of the shared form
//

import SwiftUI
import SwiftData

// simple medicine edit form
struct SimpleMedicineEditView: View {
    @State private var viewModel: MedicineEditViewModel
    var onDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focus: MedicineEditViewModel.Field?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDiscard = false

    init(medicine: MedicineInstruction?, plan: CarePlan, now: Date, onDeleted: (() -> Void)? = nil) {
        _viewModel = State(initialValue: MedicineEditViewModel(medicine: medicine, plan: plan, now: now))
        self.onDeleted = onDeleted
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            SimpleEditScaffold(title: viewModel.title, saveTitle: viewModel.saveTitle, onSave: save, onCancel: cancel) {
                SimpleTextField(label: viewModel.nameLabel, prompt: viewModel.namePrompt, text: $viewModel.draft.name, focus: $focus,
                                field: .name, problem: viewModel.problem(for: .name),
                                submitLabel: viewModel.submitLabel(for: .name),
                                capitalization: .words, autocorrect: false) { advance(.name) }
                SimpleTextField(label: viewModel.amountLabel, prompt: viewModel.amountPrompt, text: $viewModel.draft.amount, focus: $focus,
                                field: .amount, submitLabel: viewModel.submitLabel(for: .amount),
                                capitalization: .never) { advance(.amount) }

                SimpleFormHeading(title: viewModel.actionTitle)
                CapsulePicker(title: viewModel.actionTitle, options: viewModel.actionOptions,
                              selection: $viewModel.draft.action, label: { viewModel.title(for: $0) }, large: true)

                SimpleTextField(label: viewModel.purposeLabel, prompt: viewModel.purposePrompt, text: $viewModel.draft.purpose,
                                focus: $focus, field: .purpose, submitLabel: viewModel.submitLabel(for: .purpose)) { advance(.purpose) }

                if viewModel.draft.usesTimes { times }
                if viewModel.draft.action == .takeAsNeeded {
                    stepper(viewModel.maxPrompt, value: viewModel.maxPerDayValue, problem: viewModel.problem(for: .maxPerDay)) {
                        viewModel.stepMax($0)
                    }
                    stepper(viewModel.minHoursPrompt, value: viewModel.minHoursValue, problem: viewModel.problem(for: .minHours)) {
                        viewModel.stepHours($0)
                    }
                }
                if viewModel.canEditDates { dates }

                SimpleTextField(label: viewModel.notesLabel, prompt: viewModel.notesPrompt, text: $viewModel.draft.notes, focus: $focus,
                                field: .notes, submitLabel: viewModel.submitLabel(for: .notes), multiline: true) { advance(.notes) }

                if !viewModel.isNew {
                    Button { isConfirmingDelete = true } label: {
                        Label(viewModel.deleteTitle, systemImage: "trash")
                            .foregroundStyle(Color.dangerInk)
                    }
                    .buttonStyle(SimpleButtonStyle(kind: .plain))
                    .padding(.top, 4)
                }
            }
            .keyboardStepper(focus: $focus, title: { viewModel.keyboardButtonTitle(for: $0) }, advance: advance)
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(viewModel.hasChanges)
            .confirmationDialog(viewModel.discardTitle, isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog(viewModel.deleteTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(viewModel.deleteTitle, role: .destructive) {
                    onDeleted?()
                    dismiss()
                    viewModel.delete(in: context)
                }
            } message: {
                Text(viewModel.deleteMessage)
            }
        }
    }

    // MARK: - Parts

    @ViewBuilder
    private var times: some View {
        SimpleFormHeading(title: viewModel.timesTitle)
        ForEach(viewModel.draft.times.indices, id: \.self) { index in
            HStack(spacing: 10) {
                SimpleDateRow(title: "Time \(index + 1)", date: Binding(
                    get: { viewModel.time(at: index) },
                    set: { viewModel.setTime($0, at: index) }), components: .hourAndMinute)
                Button {
                    viewModel.removeTime(at: index)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title)
                        .foregroundStyle(Color.dangerInk)
                        .frame(width: FormMetrics.simpleRow, height: FormMetrics.simpleRow)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove time \(index + 1)")
            }
        }
        if let problem = viewModel.problem(for: .times) { FieldProblemText(text: problem, large: true) }
        Button {
            viewModel.addTime()
        } label: {
            Label(viewModel.addTimeTitle, systemImage: "plus")
        }
        .buttonStyle(SimpleButtonStyle(kind: .plain))
    }

    private func stepper(_ title: String, value: Int?, problem: String?, step: @escaping (Bool) -> Void) -> some View {
        SimpleFormRow(problem: problem) {
            FormStepperRow(title: title, valueText: value.map { "\($0)" } ?? viewModel.notSetText,
                           canGoDown: value != nil, large: true, step: step)
        }
    }

    @ViewBuilder
    private var dates: some View {
        @Bindable var viewModel = viewModel
        SimpleFormHeading(title: viewModel.datesTitle)
        SimpleFormRow {
            ToggleDateRow(title: viewModel.startTitle, isOn: $viewModel.hasStart, date: $viewModel.startDate, large: true)
        }
        SimpleFormRow(problem: viewModel.problem(for: .dates)) {
            ToggleDateRow(title: viewModel.endTitle, isOn: $viewModel.hasEnd, date: $viewModel.endDate, large: true)
        }
    }

    // MARK: - Actions

    private func advance(_ field: MedicineEditViewModel.Field) {
        focus = viewModel.nextField(after: field)
    }

    // asks before throwing away changes
    private func cancel() {
        if viewModel.hasChanges { isConfirmingDiscard = true } else { dismiss() }
    }

    private func save() {
        if viewModel.save(in: context) {
            dismiss()
        } else if viewModel.problem(for: .name) != nil {
            focus = .name
        }
    }
}
