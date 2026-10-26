//
//  HelpView.swift
//  Remedy
//
//  classic get help sheet
//

import SwiftUI
import SwiftData

struct HelpView: View {

    @Query(sort: \CarePlan.createdAt, order: .reverse) private var plans: [CarePlan]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let viewModel = HelpViewModel(plan: plans.first)
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.betweenCards) {
                    emergencyCard(viewModel)

                    SectionCard(title: viewModel.warningTitle, symbol: "exclamationmark.triangle.fill",
                                tone: .caution, collapsible: false, rememberAs: "help.warning") {
                        BulletList(items: viewModel.warningSigns, symbol: "exclamationmark.circle")
                        CardFootnote(text: viewModel.warningFootnote)
                    }

                    SectionCard(title: viewModel.contactsTitle, symbol: "stethoscope",
                                collapsible: false, rememberAs: "help.contacts") {
                        if viewModel.showsContacts {
                            DividedList(items: viewModel.contactRows, inset: 42) { row in
                                ContactRowView(row: row, callTitle: viewModel.callTitle)
                            }
                        } else {
                            Text(viewModel.noContactsText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, Spacing.rowVertical)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, Spacing.scrollBottom)
            }
            .background(Color.screenBackground)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.doneTitle) { dismiss() }
                }
            }
        }
    }

    // MARK: - 911 (always first)

    private func emergencyCard(_ viewModel: HelpViewModel) -> some View {
        VStack(spacing: 12) {
            CallButton(title: viewModel.emergencyTitle, phoneURL: viewModel.emergencyURL, prominent: true)
                .tint(.red)
                .controlSize(.large)
                .font(.title3.bold())
            Text(viewModel.emergencyDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.insideCard)
        .cardStyle(Tone.stop.color.opacity(0.12))
    }
}

// MARK: - One contact with a Call button

// one contact with a call button
struct ContactRowView: View {
    let row: ContactRow
    let callTitle: String

    var body: some View {
        HStack(spacing: 12) {
            IconRow(symbol: row.symbol, title: row.name, subtitle: "\(row.detail)\n\(row.phoneText)")
            if let url = row.phoneURL {
                Link(destination: url) {
                    Label(callTitle, systemImage: "phone.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .tint(Color.remedyTeal)
                .accessibilityLabel("\(callTitle) \(row.name)")
            }
        }
    }
}

#Preview(traits: .afterSurgerySample) {
    HelpView()
}
