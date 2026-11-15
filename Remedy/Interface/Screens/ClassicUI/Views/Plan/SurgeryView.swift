//
//  SurgeryView.swift
//  Remedy
//
//  classic your surgery (screen 49) and choose hospital (screen 50), every date in the plan moves with these
//

import SwiftUI
import SwiftData

// classic your surgery page
struct SurgeryView: View {
    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // UI only the row being changed and the hospital search
    @State private var editing: SurgeryScreen.Field?
    @State private var isChoosingHospital = false

    var body: some View {
        if let plan = plans.first {
            content(SurgeryScreen(plan: plan, now: AppClock.now()), plan: plan)
        }
    }

    private func content(_ screen: SurgeryScreen, plan: CarePlan) -> some View {
        List {
            Section {
                row(screen, .procedure, symbol: "bed.double", value: screen.procedure.isEmpty ? screen.notSet : screen.procedure)
                row(screen, .date, symbol: "calendar", value: screen.dateText)
                Button { isChoosingHospital = true } label: {
                    ListRow(symbol: "building.2", title: "Hospital", subtitle: screen.hospitalSubtitle, showsChevron: true)
                }
                .buttonStyle(.plain)
                Button { editing = .whereToGo } label: {
                    ListRow(symbol: "mappin.and.ellipse", title: screen.fieldTitle(.whereToGo),
                            subtitle: screen.whereToGo, value: screen.whereToGo.isEmpty ? screen.notSet : "", showsChevron: true)
                }
                .buttonStyle(.plain)
            }
            Section {
                row(screen, .arrival, symbol: "clock", value: screen.arrivalText)
                row(screen, .start, symbol: "clock", value: screen.startText)
                row(screen, .home, symbol: "calendar", value: screen.homeText)
            } header: {
                ListSectionHeader(title: screen.timesTitle)
            } footer: {
                Text(screen.footer).font(.footnote).foregroundStyle(Color.ink2)
            }
        }
        .remedyList()
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $editing) { SurgeryFieldSheet(plan: plan, field: $0) }
        .navigationDestination(isPresented: $isChoosingHospital) { HospitalSearchView(plan: plan) }
    }

    private func row(_ screen: SurgeryScreen, _ field: SurgeryScreen.Field, symbol: String, value: String) -> some View {
        Button { editing = field } label: {
            ListRow(symbol: symbol, title: screen.fieldTitle(field), value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

// one surgery field: a date, a time or a few words
struct SurgeryFieldSheet: View {
    @Bindable var plan: CarePlan
    let field: SurgeryScreen.Field

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    // UI only what is picked or typed before Save
    @State private var date = Date()
    @State private var text = ""

    var body: some View {
        let screen = SurgeryScreen(plan: plan, now: AppClock.now())
        NavigationStack {
            List {
                Section {
                    switch field {
                    case .procedure, .whereToGo:
                        TextField(screen.fieldPrompt(field), text: $text, axis: .vertical)
                            .font(.body)
                            .frame(minHeight: Spacing.minTarget)
                    case .date, .home:
                        // the system calendar with the surgery and visit days marked
                        PlanCalendarPicker(selection: $date, surgery: plan.surgeryDate, visits: plan.appointments.map(\.date))
                            .frame(minHeight: 340)
                    case .arrival, .start:
                        DatePicker(screen.fieldTitle(field), selection: $date, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                }
                if field == .date {
                    Section {
                        ListRow(symbol: "exclamationmark.triangle", tone: .caution, title: SurgeryEditWords.movesTitle,
                                subtitle: SurgeryEditWords.movesText)
                    }
                    .toneRow(.caution)
                }
            }
            .remedyList()
            .navigationTitle(field == .date ? SurgeryEditWords.dateTitle : screen.fieldTitle(field))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: load)
    }

    private func load() {
        let screen = SurgeryScreen(plan: plan, now: AppClock.now())
        let day = plan.surgeryDate ?? AppClock.now()
        let morning = DayMath.calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day
        switch field {
        case .procedure: text = plan.procedure
        case .whereToGo: text = plan.hospitalWhereToGo ?? ""
        case .date: date = day
        case .home: date = plan.dischargeDate ?? DayMath.calendar.date(byAdding: .day, value: 1, to: day) ?? day
        case .arrival: date = screen.arrival ?? morning
        case .start: date = plan.surgeryStartTime ?? screen.arrival ?? morning
        }
    }

    private func save() {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .procedure: plan.procedure = words
        case .whereToGo: plan.hospitalWhereToGo = words.isEmpty ? nil : words
        // the settings setter also moves calendar events
        case .date: SettingsViewModel(plan: plan, now: AppClock.now()).setSurgeryDate(date, in: context)
        case .home: SettingsViewModel(plan: plan, now: AppClock.now()).setDischargeDate(date, in: context)
        case .arrival: plan.arrivalTime = date
        case .start: plan.surgeryStartTime = date
        }
        context.saveNow()
        if field == .arrival || field == .date {
            Task { await LiveActivityManager.sync(plan: plan, now: AppClock.now()) }
        }
    }
}

// choose hospital (screen 50): Apple Maps search with the words typed, never the patient's location
struct HospitalSearchView: View {
    @Bindable var plan: CarePlan

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var completer = AddressCompleter()
    // UI only the words typed and the address form
    @State private var query = ""
    @State private var isTyping = false

    var body: some View {
        let screen = HospitalSearchScreen(plan: plan)
        List {
            if let papers = screen.fromPapers {
                Section {
                    ListRow(symbol: "building.2", title: papers.name, subtitle: papers.address) {
                        Image(systemName: "checkmark").foregroundStyle(Color.remedyTeal).accessibilityHidden(true)
                    }
                    .accessibilityAddTraits(.isSelected)
                } header: {
                    ListSectionHeader(title: screen.fromPapersTitle)
                }
            }
            if !completer.suggestions.isEmpty {
                Section {
                    ForEach(completer.suggestions) { suggestion in
                        Button { pick(suggestion) } label: {
                            ListRow(symbol: "building.2", title: suggestion.title, subtitle: suggestion.subtitle)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    ListSectionHeader(title: screen.otherTitle)
                }
            }
            Section {
                Button { isTyping = true } label: {
                    ListRow(symbol: "mappin.and.ellipse", title: screen.typeAddressButton, showsChevron: true)
                }
                .buttonStyle(.plain)
            }
        }
        .remedyList()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: screen.prompt)
        .onChange(of: query) { _, text in completer.update(text, hospitals: true) }
        .onDisappear { completer.cancel() }
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $isTyping) { TypeAddressSheet(plan: plan) }
    }

    // fills the hospital name and address from the picked suggestion
    private func pick(_ suggestion: PlaceSuggestion) {
        Task {
            let fill = await completer.resolve(suggestion)
            if !fill.name.isEmpty { plan.hospitalName = fill.name }
            if !fill.address.isEmpty { plan.hospitalAddress = fill.address }
            context.saveNow()
            dismiss()
        }
    }
}

// words on the surgery date pages
enum SurgeryEditWords {
    static let dateTitle = "Surgery Date"
    static let movesTitle = "This moves your whole plan"
    static let movesText = "Stop days, visits and rules move with it."
    // 101
    static let hospitalTitle = "Hospital"
    static let nameLabel = "Name"
    static let addressLabel = "Address"
    static let suggestions = "Suggestions"
    static let footer = "Suggestions come from Apple Maps search of what you type. Remedy never asks for your location."
}

// 101, a hospital Maps can't find: name and address, with suggestions from what is typed
struct TypeAddressSheet: View {
    @Bindable var plan: CarePlan

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var completer = AddressCompleter()
    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    labeled(SurgeryEditWords.nameLabel) { TextField(SurgeryEditWords.nameLabel, text: $name) }
                    labeled(SurgeryEditWords.addressLabel) {
                        TextField(SurgeryEditWords.addressLabel, text: $address)
                            .textContentType(.fullStreetAddress)
                            .onChange(of: address) { _, text in completer.update(text, hospitals: false) }
                    }
                }
                Section {
                    ForEach(completer.suggestions) { suggestion in
                        Button { pick(suggestion) } label: {
                            ListRow(symbol: "mappin.and.ellipse", title: suggestion.title, subtitle: suggestion.subtitle)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    if !completer.suggestions.isEmpty { ListSectionHeader(title: SurgeryEditWords.suggestions) }
                } footer: {
                    Text(SurgeryEditWords.footer).font(.footnote).foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .navigationTitle(SurgeryEditWords.hospitalTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() }.fontWeight(.semibold) }
            }
            .onAppear {
                name = plan.hospitalName ?? ""
                address = plan.hospitalAddress ?? ""
            }
            .onDisappear { completer.cancel() }
        }
        .presentationDetents([.large])
    }

    private func labeled<Field: View>(_ label: String, @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: 16) {
            Text(label).foregroundStyle(Color.ink2).frame(minWidth: 70, alignment: .leading)
            field()
        }
        .font(.body)
        .frame(minHeight: Spacing.minTarget)
    }

    private func pick(_ suggestion: PlaceSuggestion) {
        Task {
            let fill = await completer.resolve(suggestion)
            if !fill.address.isEmpty { address = fill.address }
            if name.isEmpty, !fill.name.isEmpty { name = fill.name }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.hospitalName = cleanName.isEmpty ? nil : cleanName
        plan.hospitalAddress = cleanAddress.isEmpty ? nil : cleanAddress
        context.saveNow()
        dismiss()
    }
}
