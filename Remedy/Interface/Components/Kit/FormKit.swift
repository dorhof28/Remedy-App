//
//  FormKit.swift
//  Remedy
//
//  the compact sizes every edit screen shares, plus a debug door for screenshots
//

import SwiftUI
import SwiftData

// row heights for forms in each look
enum FormMetrics {
    // classic rows are the standard iOS row
    static let row: CGFloat = 44
    // simple rows stay comfortable to hit
    static let simpleRow: CGFloat = 52
    // gap between stacked simple fields
    static let simpleGap: CGFloat = 10
}

#if DEBUG
// DEBUG ONLY -demoOpenEditScreen medicineNew|medicine|appointmentNew|appointment|taskNew|task opens that edit sheet for screenshots
private struct DemoEditScreen: ViewModifier {
    @Query private var plans: [CarePlan]
    @AppStorage(AppLook.storageKey) private var look: AppLook = .simple
    @State private var name: String? = UserDefaults.standard.string(forKey: "demoOpenEditScreen")

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: Binding(get: { name != nil && !plans.isEmpty }, set: { if !$0 { name = nil } })) {
            if let plan = plans.first, let name { screen(name, plan: plan) }
        }
    }

    @ViewBuilder
    private func screen(_ name: String, plan: CarePlan) -> some View {
        let now = AppClock.now()
        switch (name, look) {
        case ("medicineNew", .classic): MedicineEditView(medicine: nil, plan: plan, now: now)
        case ("medicine", .classic): MedicineEditView(medicine: plan.medicines.first, plan: plan, now: now)
        case ("appointmentNew", .classic): AppointmentEditView(appointment: nil, plan: plan, now: now)
        case ("appointment", .classic): AppointmentEditView(appointment: plan.appointments.first, plan: plan, now: now)
        case ("taskNew", .classic): TaskEditView(task: nil, plan: plan, now: now)
        case ("task", .classic): TaskEditView(task: plan.tasks.first, plan: plan, now: now)
        case ("medicineNew", _): SimpleMedicineEditView(medicine: nil, plan: plan, now: now)
        case ("medicine", _): SimpleMedicineEditView(medicine: plan.medicines.first, plan: plan, now: now)
        case ("appointmentNew", _): SimpleAppointmentEditView(appointment: nil, plan: plan, now: now)
        case ("appointment", _): SimpleAppointmentEditView(appointment: plan.appointments.first, plan: plan, now: now)
        case ("taskNew", _): SimpleTaskEditView(task: nil, plan: plan, now: now)
        default: SimpleTaskEditView(task: plan.tasks.first, plan: plan, now: now)
        }
    }
}
#endif

extension View {
    func demoEditScreen() -> some View {
        #if DEBUG
        modifier(DemoEditScreen())
        #else
        self
        #endif
    }
}
