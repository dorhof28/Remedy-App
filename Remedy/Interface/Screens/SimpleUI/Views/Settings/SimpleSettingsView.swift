//
//  SimpleSettingsView.swift
//  Remedy
//
//  simple settings
//

import SwiftUI
import SwiftData

struct SimpleSettingsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // saved on the phone RootView switches the look when it changes
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // UI only is the full Settings screen open
    @State private var isShowingMore = false

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.title) {
            Toggle(isOn: $remindersOn) {
                Label(viewModel.simpleRemindersTitle, systemImage: "bell.fill")
                    .font(.title3.bold())
            }
            .tint(Color.remedyTeal)
            .padding(18)
            .frame(minHeight: 72)
            .cardStyle()
            .onChange(of: remindersOn) { _, isOn in viewModel.setReminders(isOn) }

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    Motion.perform(reduceMotion) { look = .classic }
                } label: {
                    Label(viewModel.switchToClassicTitle, systemImage: "rectangle.grid.1x2.fill")
                }
                .buttonStyle(SimpleButtonStyle(kind: .plain))
                Text(viewModel.switchToClassicFooter)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                isShowingMore = true
            } label: {
                Label(viewModel.moreSettingsTitle, systemImage: "gearshape.fill")
            }
            .buttonStyle(SimpleButtonStyle(kind: .plain))

            Spacer(minLength: 0)

            Text(viewModel.disclaimer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isShowingMore) { SettingsView() }
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleSettingsView() }
}
