//
//  HelpView.swift
//  Remedy
//
//  classic help (screen 56): 911 first, emergency info, up to 3 people to call, then when to call
//

import SwiftUI
import SwiftData

// classic help sheet
struct HelpView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // UI only the contacts sheet and the emergency info page
    @State private var isEditing = false
    @State private var showsEmergencyInfo = false

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        NavigationStack {
            List {
                Section {
                    EmergencyCallButton(title: viewModel.emergencyTitle).plainListRow()
                } footer: {
                    Text(HelpViewModel.emergencyFootnote).font(.footnote).foregroundStyle(Color.ink2)
                }
                Section {
                    Button { showsEmergencyInfo = true } label: {
                        ListRow(symbol: "staroflife", tone: .stop, title: HelpViewModel.emergencyInfoRowTitle,
                                subtitle: HelpViewModel.emergencyInfoRowText, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    if viewModel.helpRows.isEmpty {
                        Text(viewModel.noContactsText).font(.body).foregroundStyle(Color.ink2)
                    }
                    ForEach(viewModel.helpRows) { row in
                        ListRow(symbol: "phone.fill", title: row.name, subtitle: viewModel.subtitle(row),
                                subtitleTone: row.phoneURL == nil ? .caution : .neutral) {
                            if let url = row.phoneURL {
                                Button(viewModel.callTitle) { openURL(url) }
                                    .font(.body.weight(.semibold))
                                    .buttonStyle(CapsuleFillStyle(fill: .accentSoft, text: .accentInk))
                                    .frame(minHeight: Spacing.minTarget)
                                    .accessibilityLabel("\(viewModel.callTitle) \(row.name)")
                            }
                        }
                        .contextMenu {
                            if let url = row.messageURL {
                                Button(HelpViewModel.messageTitle, systemImage: "message") { openURL(url) }
                            }
                            if let url = row.emailURL {
                                Button("Email", systemImage: "envelope") { openURL(url) }
                            }
                        }
                    }
                } header: {
                    ListSectionHeader(title: HelpViewModel.callSectionTitle, trailing: HelpViewModel.editButton) { isEditing = true }
                }
                Section {
                    ForEach(viewModel.whenRows) { item in
                        ListRow(symbol: item.tone == .stop ? "nosign" : "exclamationmark.triangle",
                                tone: item.tone == .stop ? .stop : .caution, title: item.text, subtitle: viewModel.callWho(item))
                            .accessibilityElement(children: .combine)
                    }
                } header: {
                    ListSectionHeader(title: HelpViewModel.whenTitle)
                }
            }
            .remedyList()
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(viewModel.doneTitle) { dismiss() } }
            }
            .navigationDestination(isPresented: $showsEmergencyInfo) { EmergencyInfoView() }
            .sheet(isPresented: $isEditing) { HelpContactsSheet() }
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    HelpView()
}
