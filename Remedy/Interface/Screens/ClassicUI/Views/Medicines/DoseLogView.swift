//
//  DoseLogView.swift
//  Remedy
//
//  screen 34 every dose by day, a tap changes the answer
//

import SwiftUI
import SwiftData

// earlier doses of one medicine, tap one to change it
struct DoseLogView: View {
    let medicine: MedicineInstruction

    @Environment(\.modelContext) private var context
    // redraws when an answer changes
    @Query private var logs: [DoseLog]
    // UI only the dose being changed
    @State private var picked: DoseSlot?

    var body: some View {
        let screen = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
        let days = screen.doseLogDays
        List {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                Section {
                    ForEach(day.rows) { line in
                        Button { picked = line.dose } label: {
                            ListRow(symbol: line.symbol, tone: line.tone, title: line.title, subtitle: line.subtitle,
                                    subtitleTone: line.subtitleTone)
                        }
                        .buttonStyle(.plain)
                        .disabled(line.dose == nil)
                    }
                } header: {
                    ListSectionHeader(title: day.title)
                } footer: {
                    if index == days.count - 1 {
                        Text(screen.doseLogFooter)
                            .font(.subheadline)
                            .foregroundStyle(Color.ink2)
                    }
                }
            }
        }
        .remedyList()
        .navigationTitle(screen.doseLogTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $picked) { slot in
            ChangeDoseSheet(medicine: medicine, slot: slot)
        }
    }
}

// 94, change a dose's answer or time, marked changed by you
struct ChangeDoseSheet: View {
    let medicine: MedicineInstruction
    let slot: DoseSlot

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var took = true
    @State private var time = Date()
    @State private var asksClear = false

    var body: some View {
        let screen = MedicineDetailViewModel(medicine: medicine, now: AppClock.now())
        NavigationStack {
            List {
                Section {
                    RadioRow(title: screen.logTookButton, isOn: took) { Motion.run { took = true } }
                    RadioRow(title: screen.logSkipButton, isOn: !took) { Motion.run { took = false } }
                } header: {
                    Text(MedicineText.everydayName(medicine))
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                        .textCase(nil)
                        .padding(.leading, -12)
                }
                // the wheel hides when skipped
                if took {
                    Section {
                        DatePicker(screen.changeTimeHeader, selection: $time, in: ...AppClock.now(),
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    } header: {
                        ListSectionHeader(title: screen.changeTimeHeader)
                    } footer: {
                        Text(screen.changedFooter).font(.footnote).foregroundStyle(Color.ink2)
                    }
                }
                if slot.log != nil {
                    Section {
                        Button(screen.logClearButton, role: .destructive) { asksClear = true }
                            .frame(maxWidth: .infinity)
                            .confirmationDialog(screen.clearAskTitle, isPresented: $asksClear, titleVisibility: .visible) {
                                Button(screen.logClearButton, role: .destructive) {
                                    screen.setAnswer(nil, for: slot, in: context)
                                    dismiss()
                                }
                                Button("Cancel", role: .cancel) {}
                            }
                    }
                }
            }
            .remedyList()
            .navigationTitle(screen.changeTitle(slot))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        screen.change(slot, to: took ? .taken : .skipped, takenAt: time, in: context)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                took = slot.log?.status != .skipped
                time = screen.startTime(slot)
            }
        }
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: slot.log?.changedByYou)
    }
}
