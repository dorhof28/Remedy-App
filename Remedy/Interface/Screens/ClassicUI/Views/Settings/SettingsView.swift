//
//  SettingsView.swift
//  Remedy
//
//  classic settings
//

import SwiftUI
import SwiftData

struct SettingsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // UI only the "Are you sure?" checks
    @State private var isConfirmingClearChat = false
    @State private var isConfirmingDeletePlan = false
    @State private var isScanningMore = false
    @State private var remindersMessage: String?
    // typed key and a counter to redraw the ai section
    @State private var keyDraft = ""
    @State private var keyVersion = 0
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @AppStorage(HealthService.stepsOnKey) private var healthStepsOn = false
    @AppStorage(GeminiPageReader.enabledKey) private var sendsPictures = true
    // saved on the phone RootView switches the look when it changes
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .remedy
    // UI only the theme tapped here saved when Settings closes so this sheet stays open
    @State private var pickedTheme: AppTheme?

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        NavigationStack {
            Form {
                if viewModel.hasPlan {
                    surgerySection(viewModel)
                }

                Section {
                    Picker(viewModel.lookTitle, selection: $look) {
                        ForEach(viewModel.looks) { option in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                Text(option.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text(viewModel.lookTitle)
                } footer: {
                    Text(viewModel.lookFooter)
                }

                Section {
                    ThemePicker(theme: Binding(get: { pickedTheme ?? theme }, set: { pickedTheme = $0 }))
                } header: {
                    Text(viewModel.themeTitle)
                } footer: {
                    Text(viewModel.themeFooter)
                }

                if viewModel.hasPlan {
                    Section {
                        Button(viewModel.scanMoreTitle, systemImage: "doc.text.viewfinder") {
                            isScanningMore = true
                        }
                    } header: {
                        Text(viewModel.papersTitle)
                    } footer: {
                        Text(viewModel.scanMoreFooter)
                    }
                }

                Section {
                    Toggle(viewModel.remindersToggle, isOn: $remindersOn)
                        .onChange(of: remindersOn) { _, isOn in viewModel.setReminders(isOn) }
                    if viewModel.hasOpenTasks {
                        Button(viewModel.addToRemindersTitle, systemImage: "checklist") {
                            Task { remindersMessage = await viewModel.addTasksToReminders() }
                        }
                    }
                } header: {
                    Text(viewModel.remindersTitle)
                } footer: {
                    Text(viewModel.remindersFooter)
                }

                Section {
                    LabeledContent(viewModel.aiUsesLabel, value: viewModel.aiStatusText)
                    if viewModel.hasGeminiKey {
                        Toggle(viewModel.picturesToggle, isOn: $sendsPictures)
                        Button(viewModel.removeKeyTitle, role: .destructive) {
                            viewModel.removeGeminiKey()
                            keyVersion += 1
                        }
                    } else {
                        SecureField(viewModel.geminiKeyPrompt, text: $keyDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(viewModel.saveKeyTitle) {
                            viewModel.saveGeminiKey(keyDraft)
                            keyDraft = ""
                            keyVersion += 1
                        }
                        .disabled(!viewModel.canSave(keyDraft))
                    }
                } header: {
                    Text(viewModel.aiTitle)
                } footer: {
                    Text(viewModel.aiFooter)
                }
                .id(keyVersion)

                if viewModel.showsHealth {
                    Section {
                        Toggle(viewModel.healthStepsToggle, isOn: $healthStepsOn)
                            .onChange(of: healthStepsOn) { _, isOn in viewModel.setHealthSteps(isOn) }
                    } header: {
                        Text(viewModel.healthTitle)
                    } footer: {
                        Text(viewModel.healthFooter)
                    }
                }

                Section {
                    NavigationLink {
                        ConnectionCheckView()
                    } label: {
                        Label(viewModel.connectionsTitle, systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                Section(viewModel.privacyTitle) {
                    Label(viewModel.privacyText, systemImage: "lock.shield")
                        .font(.subheadline)
                    Button(viewModel.clearChatTitle, role: .destructive) {
                        isConfirmingClearChat = true
                    }
                    if viewModel.hasPlan {
                        Button(viewModel.deletePlanTitle, role: .destructive) {
                            isConfirmingDeletePlan = true
                        }
                    }
                }

                Section {
                    LabeledContent(viewModel.versionLabel, value: viewModel.versionText)
                    LabeledContent(viewModel.creditsLabel, value: viewModel.creditsText)
                } header: {
                    Text(viewModel.aboutTitle)
                } footer: {
                    Text(viewModel.disclaimer)
                }

                if viewModel.showsDemo {
                    Section(viewModel.demoTitle) {
                        Label(viewModel.demoText, systemImage: "film")
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                if let pickedTheme { theme = pickedTheme }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.doneTitle) { dismiss() }
                }
            }
            .alert(viewModel.remindersTitle, isPresented: Binding(get: { remindersMessage != nil },
                                                                   set: { if !$0 { remindersMessage = nil } })) {
                Button("OK") { remindersMessage = nil }
            } message: {
                Text(remindersMessage ?? "")
            }
            .sheet(isPresented: $isScanningMore) {
                ScanFlowView(isAddingPapers: true, planHasSurgeryDate: viewModel.hasSurgeryDate)
            }
            .confirmationDialog(viewModel.clearChatTitle, isPresented: $isConfirmingClearChat, titleVisibility: .visible) {
                Button(viewModel.clearChatTitle, role: .destructive) { viewModel.clearChat(in: context) }
            } message: {
                Text(viewModel.clearChatMessage)
            }
            .confirmationDialog(viewModel.deletePlanTitle, isPresented: $isConfirmingDeletePlan, titleVisibility: .visible) {
                Button(viewModel.deletePlanTitle, role: .destructive) {
                    viewModel.deletePlan(in: context)
                    dismiss()
                }
            } message: {
                Text(viewModel.deletePlanMessage)
            }
        }
    }

    // MARK: - Your surgery

    private func surgerySection(_ viewModel: SettingsViewModel) -> some View {
        Section {
            LabeledContent(viewModel.procedureLabel, value: viewModel.procedure)
            // the pickers save straight away through the ViewModel
            DatePicker(viewModel.surgeryDateLabel,
                       selection: Binding(get: { viewModel.surgeryDate },
                                          set: { viewModel.setSurgeryDate($0, in: context) }),
                       displayedComponents: .date)
            DatePicker(viewModel.dischargeDateLabel,
                       selection: Binding(get: { viewModel.dischargeDate },
                                          set: { viewModel.setDischargeDate($0, in: context) }),
                       displayedComponents: .date)
        } header: {
            Text(viewModel.surgeryTitle)
        } footer: {
            Text(viewModel.dateFootnote)
        }
    }
}

#Preview(traits: .beforeSurgerySample) {
    SettingsView()
}
