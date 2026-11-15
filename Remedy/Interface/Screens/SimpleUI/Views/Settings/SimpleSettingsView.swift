//
//  SimpleSettingsView.swift
//  Remedy
//
//  simple settings
//

import SwiftUI
import SwiftData

// simple settings
struct SimpleSettingsView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]

    // only here so the row values redraw when they change
    @AppStorage(AppLook.storageKey) private var look: AppLook = .classic
    @AppStorage(NotificationService.enabledKey) private var remindersOn = true
    @AppStorage(AppLock.settingKey) private var lockOn = false
    @AppStorage(ModelSettings.plannerKey) private var plannerID = ModelChoice.ID.onPhone.rawValue

    var body: some View {
        let viewModel = SettingsViewModel(plan: plans.first, now: AppClock.now())
        SimpleScreen(title: viewModel.title) {
            // short rows in small groups, each opens its own screen
            ForEach(viewModel.pageGroups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(Color.ink2)
                        .padding(.leading, 4)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(group.pages) { page in
                        NavigationLink(value: page) {
                            SimpleSettingsRow(symbol: page.symbol, tone: page.tone, title: viewModel.pageTitle(page),
                                              value: viewModel.pageValue(page))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
            BrandFooter(motto: viewModel.motto)
        }
        .navigationDestination(for: SettingsViewModel.Page.self) { page in
            switch page {
            case .plan: SimplePlanPage()
            case .papers: SimplePapersPage()
            case .reminders: SimpleRemindersPage()
            case .reading: SimpleReadingPage()
            case .privacy: SimplePrivacyPage()
            case .appearance: SimpleAppearancePage()
            case .data: SimpleDataPage()
            case .demo: SimpleDemoSettingsPage()
            case .about: SimpleAboutPage()
            }
        }
    }
}

// one big row: icon, title, current value, arrow
struct SimpleSettingsRow: View {
    let symbol: String
    var tone: Tone = .info
    let title: String
    var value: String = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 14) {
            ItemIconTile(kind: .custom(symbol: symbol, tone: tone), size: 44)
            Text(title)
                .font(.title3.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            if !value.isEmpty && typeSize < .xxLarge {
                Text(value)
                    .font(.title3)
                    .foregroundStyle(Color.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Image(systemName: "chevron.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.inactive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        // the same soft card as the rest of the simple look
        .cardStyle()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview(traits: .afterSurgerySample) {
    NavigationStack { SimpleSettingsView() }
}
