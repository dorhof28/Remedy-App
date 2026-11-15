//
//  TaskEditView.swift
//  Remedy
//
//  classic add or change a to do, the shared grouped form
//

import SwiftUI
import SwiftData

// classic to-do edit form
struct TaskEditView: View {
    @State private var viewModel: TaskEditViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @FocusState private var focus: Bool?
    @State private var isConfirmingDelete = false

    init(task: CareTask?, plan: CarePlan, now: Date) {
        _viewModel = State(initialValue: TaskEditViewModel(task: task, plan: plan, now: now))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                FormCard {
                    FormTextRow(label: viewModel.titleLabel, prompt: viewModel.titlePrompt, text: $viewModel.draft.title,
                                focus: $focus, field: true, problem: viewModel.titleProblem, multiline: true,
                                submitLabel: .done) { save() }
                }

                if viewModel.canEditDay {
                    FormCard {
                        // toggle and date on one row like every edit form
                        ToggleDateRow(title: viewModel.dayTitle, isOn: $viewModel.hasDay, date: $viewModel.dueDate)
                    }
                }

                if !viewModel.isNew {
                    FormCard {
                        Button(viewModel.deleteTitle, role: .destructive) { isConfirmingDelete = true }
                            .foregroundStyle(Color.dangerInk)
                            .frame(maxWidth: .infinity, minHeight: FormMetrics.row)
                    }
                }
            }
            .remedyFormStyle()
            .formSheetChrome(title: viewModel.title, saveTitle: viewModel.saveTitle, onClose: { dismiss() }, onSave: save)
            .confirmationDialog(viewModel.deleteTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(viewModel.deleteTitle, role: .destructive) {
                    dismiss()
                    viewModel.delete(in: context)
                }
            } message: {
                Text(viewModel.deleteMessage)
            }
            .onAppear { if viewModel.isNew { focus = true } }
        }
    }

    private func save() {
        if viewModel.save(in: context) { dismiss() } else { focus = true }
    }
}
