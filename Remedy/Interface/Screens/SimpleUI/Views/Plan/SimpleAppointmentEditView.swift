//
//  SimpleAppointmentEditView.swift
//  Remedy
//
//  simple add or change a visit
//

import SwiftUI
import SwiftData

// simple visit edit form
struct SimpleAppointmentEditView: View {
    @State private var viewModel: AppointmentEditViewModel
    var onDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focus: AppointmentEditViewModel.Field?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingDiscard = false

    init(appointment: Appointment?, plan: CarePlan, now: Date, onDeleted: (() -> Void)? = nil) {
        _viewModel = State(initialValue: AppointmentEditViewModel(appointment: appointment, plan: plan, now: now))
        self.onDeleted = onDeleted
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            SimpleEditScaffold(title: viewModel.title, saveTitle: viewModel.saveTitle, onSave: save, onCancel: cancel) {
                SimpleTextField(label: viewModel.titleLabel, prompt: viewModel.titlePrompt, text: $viewModel.draft.title, focus: $focus,
                                field: .title, problem: viewModel.titleProblem,
                                submitLabel: viewModel.submitLabel(for: .title)) { advance(.title) }
                SimpleDateRow(title: viewModel.dayLabel, date: $viewModel.draft.date)
                SimpleDateRow(title: viewModel.timeLabel, date: $viewModel.draft.date, components: .hourAndMinute)
                SimpleTextField(label: viewModel.doctorLabel, prompt: viewModel.doctorPrompt, text: $viewModel.draft.doctor, focus: $focus,
                                field: .doctor, submitLabel: viewModel.submitLabel(for: .doctor),
                                capitalization: .words) { advance(.doctor) }
                SimpleTextField(label: viewModel.placeLabel, prompt: viewModel.placePrompt, text: $viewModel.draft.place, focus: $focus,
                                field: .place, submitLabel: viewModel.submitLabel(for: .place),
                                capitalization: .words) { advance(.place) }
                SimpleTextField(label: viewModel.phoneLabel, prompt: viewModel.phonePrompt, text: $viewModel.draft.phone, focus: $focus,
                                field: .phone, keyboard: .phonePad) { advance(.phone) }
                SimpleTextField(label: viewModel.notesLabel, prompt: viewModel.notesPrompt, text: $viewModel.draft.notes, focus: $focus,
                                field: .notes, submitLabel: viewModel.submitLabel(for: .notes), multiline: true) { advance(.notes) }

                SimpleToggleRow(title: viewModel.calendarTitle, isOn: $viewModel.addsToCalendar)
                if viewModel.addsToCalendar, !viewModel.calendars.isEmpty {
                    calendarChoices
                }
                if viewModel.calendarDenied {
                    Text(viewModel.calendarDeniedText).font(.title3).foregroundStyle(Color.ink2)
                } else if !viewModel.calendarNote.isEmpty {
                    Text(viewModel.calendarNote).font(.title3).foregroundStyle(Color.ink2)
                }

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
            .task(id: viewModel.addsToCalendar) {
                if viewModel.addsToCalendar { await viewModel.loadCalendars() }
            }
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

    // one calendar to pick, shown as big choices
    @ViewBuilder
    private var calendarChoices: some View {
        ForEach(viewModel.calendars) { calendar in
            SimpleChoiceRow(title: calendar.title, isSelected: viewModel.calendarID == calendar.id) {
                viewModel.calendarID = calendar.id
            }
        }
    }

    private func advance(_ field: AppointmentEditViewModel.Field) {
        focus = viewModel.nextField(after: field)
    }

    // asks before throwing away changes
    private func cancel() {
        if viewModel.hasChanges { isConfirmingDiscard = true } else { dismiss() }
    }

    private func save() {
        guard !viewModel.isSaving else { return }
        focus = nil
        Task {
            if await viewModel.save(in: context) { dismiss() } else { focus = .title }
        }
    }
}
