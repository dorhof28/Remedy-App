//
//  AppointmentEditView.swift
//  Remedy
//
//  classic add or change a visit, the shared grouped form
//

import SwiftUI
import SwiftData

// classic visit edit form
struct AppointmentEditView: View {
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
            Form {
                FormCard {
                    FormTextRow(label: viewModel.titleLabel, prompt: viewModel.titlePrompt, text: $viewModel.draft.title,
                                focus: $focus, field: .title, problem: viewModel.titleProblem,
                                submitLabel: viewModel.submitLabel(for: .title)) { advance(.title) }
                    DatePillRow(title: viewModel.dayLabel, date: $viewModel.draft.date)
                    DatePillRow(title: viewModel.timeLabel, date: $viewModel.draft.date, components: .hourAndMinute)
                }

                FormCard {
                    FormTextRow(label: viewModel.doctorLabel, prompt: viewModel.doctorPrompt, text: $viewModel.draft.doctor,
                                focus: $focus, field: .doctor, capitalization: .words,
                                submitLabel: viewModel.submitLabel(for: .doctor)) { advance(.doctor) }
                        .textContentType(.name)
                    FormTextRow(label: viewModel.placeLabel, prompt: viewModel.placePrompt, text: $viewModel.draft.place,
                                focus: $focus, field: .place, capitalization: .words,
                                submitLabel: viewModel.submitLabel(for: .place)) { advance(.place) }
                    FormTextRow(label: viewModel.phoneLabel, prompt: viewModel.phonePrompt, text: $viewModel.draft.phone,
                                focus: $focus, field: .phone, keyboard: .phonePad,
                                submitLabel: viewModel.submitLabel(for: .phone)) { advance(.phone) }
                        .textContentType(.telephoneNumber)
                }

                FormCard {
                    FormTextRow(label: viewModel.notesLabel, prompt: viewModel.notesPrompt, text: $viewModel.draft.notes,
                                focus: $focus, field: .notes, multiline: true,
                                submitLabel: viewModel.submitLabel(for: .notes)) { advance(.notes) }
                }

                calendarSection

                if !viewModel.isNew {
                    FormCard {
                        Button(viewModel.deleteTitle, role: .destructive) { isConfirmingDelete = true }
                            .foregroundStyle(Color.dangerInk)
                            .frame(maxWidth: .infinity, minHeight: FormMetrics.row)
                    }
                }
            }
            .remedyFormStyle()
            .formSheetChrome(title: viewModel.title, saveTitle: viewModel.saveTitle, onClose: close, onSave: save)
            .keyboardStepper(focus: $focus, title: { viewModel.keyboardButtonTitle(for: $0) }, advance: advance)
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

    private var calendarSection: some View {
        @Bindable var viewModel = viewModel
        let footer = viewModel.calendarDenied ? viewModel.calendarDeniedText : viewModel.calendarNote
        return FormCard(footer: footer) {
            Toggle(isOn: $viewModel.addsToCalendar) {
                Text(viewModel.calendarTitle).font(.body.weight(.semibold)).foregroundStyle(Color.ink)
            }
            .tint(Color.accentInk)
            .frame(minHeight: FormMetrics.row)
            if viewModel.addsToCalendar, !viewModel.calendars.isEmpty {
                Picker(viewModel.calendarLabel, selection: $viewModel.calendarID) {
                    ForEach(viewModel.calendars) { calendar in
                        Text("\(calendar.title) (\(calendar.account))").tag(Optional(calendar.id))
                    }
                }
                .tint(Color.accentInk)
                .frame(minHeight: FormMetrics.row)
            }
        }
    }

    private func advance(_ field: AppointmentEditViewModel.Field) {
        focus = viewModel.nextField(after: field)
    }

    // asks before throwing away changes
    private func close() {
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
