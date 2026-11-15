//
//  RestartSheet.swift
//  Remedy
//
//  screen 36 who said a stopped medicine is OK and when, then the edit form
//

import SwiftUI

// who said a stopped medicine is ok again and from when
struct RestartSheet: View {
    let medicineName: String
    let onContinue: (_ who: String, _ date: Date) -> Void

    @Environment(\.dismiss) private var dismiss
    // UI only the picks
    @State private var who = RestartRule.whoOptions[0]
    @State private var date = AppClock.now()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(RestartRule.whoOptions, id: \.self) { name in
                        Button { who = name } label: {
                            ListRow(title: name) { EmptyView() }
                                .leadingMark(who == name ? "largecircle.fill.circle" : "circle", isOn: who == name)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(who == name ? .isSelected : [])
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Only restart if a doctor told you it\u{2019}s OK.")
                            .font(.body)
                            .foregroundStyle(Color.ink2)
                            .textCase(nil)
                            .padding(.leading, -16)
                        ListSectionHeader(title: "Who said it\u{2019}s OK?")
                    }
                }
                Section {
                    ListRow(symbol: "calendar", title: "When") {
                        DatePicker("When", selection: $date, in: ...AppClock.now(), displayedComponents: .date)
                            .labelsHidden()
                    }
                } footer: {
                    Text("Next, set how to take it: every day or only when needed, how much and when.")
                        .font(.subheadline)
                        .foregroundStyle(Color.ink2)
                }
            }
            .remedyList()
            .navigationTitle("Restart \(medicineName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue") {
                    onContinue(who, date)
                    dismiss()
                }
                .padding(.horizontal, Spacing.screenEdge)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.large])
    }
}
