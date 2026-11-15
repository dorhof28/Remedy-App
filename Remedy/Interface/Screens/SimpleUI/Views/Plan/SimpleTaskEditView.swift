//
//  SimpleTaskEditView.swift
//  Remedy
//
//  simple add or change a to do, the big version of the shared form
//

import SwiftUI
import SwiftData

// simple to-do edit form
struct SimpleTaskEditView: View {
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
            SimpleEditScaffold(title: viewModel.title, saveTitle: viewModel.saveTitle, onSave: save, onCancel: { dismiss() }) {
                SimpleTextField(label: viewModel.titleLabel, prompt: viewModel.titlePrompt, text: $viewModel.draft.title,
                                focus: $focus, field: true, problem: viewModel.titleProblem, submitLabel: .done) { save() }
                if viewModel.canEditDay {
                    // toggle and day in one big row like every edit form
                    SimpleFormRow {
                        ToggleDateRow(title: viewModel.dayTitle, isOn: $viewModel.hasDay, date: $viewModel.dueDate, large: true)
                    }
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
            .toolbar(.hidden, for: .navigationBar)
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
