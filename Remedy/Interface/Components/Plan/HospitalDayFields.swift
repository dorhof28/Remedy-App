//
//  HospitalDayFields.swift
//  Remedy
//
//  arrival time, hospital and the busy day checklist, used by both looks on the plan screen
//

import SwiftUI
import SwiftData

// hospital, where to go and surgery day times, edited in place
struct HospitalDayFields: View {
    @Bindable var plan: CarePlan
    var simple = false

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: Field?
    @State private var completer = AddressCompleter()
    // UI only bumped after a tick so the list reads the saved ticks again
    @State private var ticks = 0

    // the two text fields, in the order Next moves through them
    enum Field: Hashable { case name, address }

    private var font: Font { simple ? .title3 : .body }

    // arrival time as a binding that fills the optional
    private var arrival: Binding<Date> {
        Binding(get: { plan.arrivalTime ?? DayChecklist.arrival(for: plan) ?? AppClock.now() },
                set: { plan.arrivalTime = $0; context.saveNow() })
    }

    private func text(_ keyPath: ReferenceWritableKeyPath<CarePlan, String?>) -> Binding<String> {
        Binding(get: { plan[keyPath: keyPath] ?? "" },
                set: { plan[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }

    private var hasArrival: Bool { plan.arrivalTime != nil || DayChecklist.arrival(for: plan) != nil }

    // a morning start on the day of surgery, the patient moves it to the real time
    private var suggestedArrival: Date {
        let day = plan.surgeryDate ?? AppClock.now()
        return DayMath.calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: focus) { _, field in
                    if field == nil { context.saveNow() }
                    guard let field else { return }
                    // wait for the keyboard so the field lands above it
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        withAnimation(reduceMotion ? nil : Motion.standard) { proxy.scrollTo(field, anchor: .center) }
                    }
                }
        }
        .onDisappear { completer.cancel() }
        .keyboardStepper(focus: $focus, title: { $0 == .name ? "Next" : "Done" }) { field in
            focus = field == .name ? .address : nil
        }
        #if DEBUG
        // screenshots open the sheet with the keyboard up on the address
        .task {
            guard UserDefaults.standard.string(forKey: "demoOpenSimpleScreen") == "surgeryDayTyping" else { return }
            try? await Task.sleep(for: .milliseconds(800))
            focus = .address
        }
        #endif
    }

    private var content: some View {
        let model = TodayViewModel(plan: plan, now: AppClock.now())
        _ = ticks
        return VStack(alignment: .leading, spacing: simple ? 10 : 6) {
            if plan.surgeryDate != nil {
                arrivalRow
                fieldBox("Hospital name", symbol: "building.2", field: .name, keyPath: \.hospitalName,
                         content: .organizationName, submit: .next, capitalization: .words)
                fieldBox("Hospital address", symbol: "mappin.and.ellipse", field: .address, keyPath: \.hospitalAddress,
                         content: .fullStreetAddress, submit: .done, capitalization: .words)
                if plan.arrivalTime == nil, DayChecklist.arrival(for: plan) != nil {
                    Text("Read from your papers. Change it if it is wrong.")
                        .font(simple ? .body : .footnote).foregroundStyle(Color.ink2)
                }
            }
            let items = model.checklist
            if !items.isEmpty {
                Rectangle().fill(Color.hairline).frame(height: 1)
                Text("Today\u{2019}s checklist")
                    .font(simple ? .title3.bold() : .headline)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                ForEach(items) { item in
                    if item.isAutomatic {
                        checklistRow(item)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(item.isDone ? .isSelected : [])
                    } else {
                        Button {
                            model.toggleChecklist(item, in: context)
                            ticks += 1
                        } label: {
                            checklistRow(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(item.isDone ? .isSelected : [])
                    }
                }
            }
        }
        // typed text is saved when the patient leaves, not only on return
        .onDisappear { context.saveNow() }
        .onChange(of: plan.arrivalTime) { _, _ in
            Task { await LiveActivityManager.sync(plan: plan, now: AppClock.now()) }
        }
    }

    // one checklist line, at least 44 points tall so a tap lands
    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(font).foregroundStyle(item.isDone ? Color.ink2 : Color.ink)
                    .strikethrough(item.isDone, color: .ink3)
                if let time = item.time {
                    Text(DayMath.timeText(of: time)).font(simple ? .body : .subheadline).foregroundStyle(Color.ink2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            TaskCheckMark(isDone: item.isDone, large: simple)
        }
        .frame(minHeight: simple ? FormMetrics.simpleRow : FormMetrics.row)
        .contentShape(Rectangle())
    }

    // the label on the left and the time or a button on the right, the same row either way so nothing jumps
    private var arrivalRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { arrivalLabel; Spacer(minLength: 8); arrivalControl }
            VStack(alignment: .leading, spacing: 8) { arrivalLabel; arrivalControl }
        }
        .frame(minHeight: simple ? FormMetrics.simpleRow : FormMetrics.row)
    }

    private var arrivalLabel: some View {
        Label("Arrival time", systemImage: "clock")
            .font(font)
            .foregroundStyle(Color.ink)
            .labelStyle(.titleAndIcon)
    }

    @ViewBuilder
    private var arrivalControl: some View {
        if hasArrival {
            // the compact picker opens a wheel, so there is no typing
            DatePicker("Arrival time", selection: arrival, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .scaleEffect(simple ? 1.15 : 1, anchor: .trailing)
        } else {
            Button("Set time") {
                focus = nil
                plan.arrivalTime = suggestedArrival
                context.saveNow()
            }
            .font(font.bold())
            .foregroundStyle(Color.accentInk)
            .padding(.horizontal, 16)
            .frame(minHeight: simple ? FormMetrics.simpleRow : FormMetrics.row)
            .background(Capsule().fill(Color.accentSoft))
            .buttonStyle(.plain)
        }
    }

    // the text a pick just wrote, so filling a box does not search again
    @State private var pickedTexts: [String] = []

    private func suggestionList(for field: Field) -> some View {
        VStack(spacing: 0) {
            ForEach(completer.suggestions) { suggestion in
                Button {
                    pick(suggestion, from: field)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title).font(font).foregroundStyle(Color.ink)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle).font(simple ? .body : .subheadline).foregroundStyle(Color.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(minHeight: simple ? FormMetrics.simpleRow : FormMetrics.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel([suggestion.title, suggestion.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
                .accessibilityHint("Fills in the hospital and address")
                if suggestion != completer.suggestions.last {
                    Rectangle().fill(Color.hairline).frame(height: 1)
                }
            }
        }
        .remedyFieldBackground(focused: false)
    }

    // fills the name and the full address from one tap
    private func pick(_ suggestion: PlaceSuggestion, from field: Field) {
        Task {
            let fill = await completer.resolve(suggestion)
            pickedTexts = [fill.name, fill.address]
            focus = nil
            if !fill.name.isEmpty, field == .name || (plan.hospitalName ?? "").isEmpty {
                plan.hospitalName = fill.name
            }
            if !fill.address.isEmpty { plan.hospitalAddress = fill.address }
            completer.cancel()
            context.saveNow()
        }
    }

    // a label above a clear box, the keyboard returns Next and then Done
    private func fieldBox(_ title: String, symbol: String, field: Field,
                          keyPath: ReferenceWritableKeyPath<CarePlan, String?>,
                          content: UITextContentType, submit: SubmitLabel,
                          capitalization: TextInputAutocapitalization) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(simple ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(Color.ink2)
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(Color.ink2)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                TextField(title, text: text(keyPath))
                    .textFieldStyle(.plain)
                    .font(font)
                    .textContentType(content)
                    .textInputAutocapitalization(capitalization)
                    .submitLabel(submit)
                    .focused($focus, equals: field)
                    .onSubmit {
                        context.saveNow()
                        focus = field == .name ? .address : nil
                    }
                if focus == field, !(plan[keyPath: keyPath] ?? "").isEmpty {
                    Button {
                        plan[keyPath: keyPath] = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title.lowercased())")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: simple ? FormMetrics.simpleRow : FormMetrics.row)
            .remedyFieldBackground(focused: focus == field)
            .contentShape(Rectangle())
            .onTapGesture { focus = field }
            if focus == field, !completer.suggestions.isEmpty {
                suggestionList(for: field)
            }
        }
        .onChange(of: plan[keyPath: keyPath] ?? "") { _, value in
            // only while typing, not when a pick fills the box
            guard focus == field, !pickedTexts.contains(value) else { return }
            completer.update(value, hospitals: field == .name)
        }
        .id(field)
    }
}
